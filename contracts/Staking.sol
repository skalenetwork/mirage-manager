// cSpell:words unstake

// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Staking.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   fair-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   fair-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
 */
pragma solidity ^0.8.24;

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IRewardWallet } from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";

import { Nodes } from "./Nodes.sol";
import { TypedMap } from "./structs/typed/TypedMap.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";
import { ExitQueueLibrary, Timestamp } from "./utils/ExitQueue.sol";
import { Credit, FundLibrary, Fair, Holder } from "./utils/Fund.sol";

/**
 * @title Staking
 * @notice Manages staking, rewards, and related features for Fair Network.
 */
contract Staking is AccessManagedUpgradeable, ReentrancyGuardUpgradeable, IStaking {

    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using FundLibrary for FundLibrary.Fund;
    using TypedSet for TypedSet.NodeIdSet;
    using TypedMap for TypedMap.HolderToCreditMap;
    using TypedMap for TypedMap.NodeIdToFairMap;
    using ExitQueueLibrary for ExitQueueLibrary.ExitQueue;

    /// @notice Default fee rate for nodes
    uint16 public constant DEFAULT_FEE_RATE = 1000;

    /// @notice The Committee contract interface
    ICommittee public committee;
    /// @notice The Nodes contract interface
    INodes public nodes;
    /// @notice The reference for the RewardWallet implementation
    IRewardWallet public rewardWalletReference;
    /// @notice The total stake of disabled nodes
    Fair public totalDisabled;
    /// @notice The maximum stake allowed per node
    Fair public stakeLimit;
    /// @notice The minimum self-stake required for a node
    Fair public selfStakeRequirement;

    FundLibrary.Fund private _rootFund;
    ExitQueueLibrary.ExitQueue private _exitQueue;
    mapping(NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;
    mapping(NodeId node => IRewardWallet rewardWallet) private _rewardWallets;
    mapping(NodeId node => EnumerableSet.AddressSet allowedReceivers) private _nodesAllowedReceivers;
    mapping(address holder => TypedSet.NodeIdSet nodeIds) private _stakedNodes;
    TypedMap.NodeIdToFairMap private _disabledNodesBalances;

    /**
     * @notice Emitted when an allowed receiver is added for a node
     * @param node The ID of the node.
     * @param receiver The address of the receiver.
     */
    event AllowedReceiverAdded(NodeId indexed node, address indexed receiver);
    /**
     * @notice Emitted when an allowed receiver is removed for a node
     * @param node The ID of the node.
     * @param receiver The address of the receiver.
     */
    event AllowedReceiverRemoved(NodeId indexed node, address indexed receiver);
    /**
     * @notice Emitted when a fee claim is requested
     * @param node The ID of the node.
     * @param from The address of the requester.
     * @param to The address of the receiver.
     * @param amount The amount of the fee claim.
     */
    event FeeClaimRequested(NodeId indexed node, address from, address indexed to, Fair indexed amount);
    /**
     * @notice Emitted when a reward is received for a node
     * @param node The ID of the node.
     * @param amount The amount of the reward.
     */
    event NodeRewardReceived(NodeId indexed node, Fair indexed amount);
    /**
     * @notice Emitted when a retrieve is requested
     * @param sender The address of the requester.
     * @param node The ID of the node.
     * @param amount The amount of the retrieve.
     */
    event RetrieveRequested(address indexed sender, NodeId indexed node, Fair indexed amount);
    /**
     * @notice Emitted when a reward is received
     * @param sender The address of the sender.
     * @param amount The amount of the reward.
     */
    event RewardReceived(address indexed sender, uint256 indexed amount);
    /**
     * @notice Emitted when a reward wallet is created for a node
     * @param node The ID of the node.
     */
    event RewardWalletCreated(NodeId indexed node);
    /**
     * @notice Emitted when a user stakes to a node
     * @param sender The address of the staker.
     * @param node The ID of the node.
     * @param amount The amount staked.
     */
    event Staked(address indexed sender, NodeId indexed node, Fair indexed amount);
    /**
     * @notice Emitted when a user stakes to a new node
     * @param sender The address of the staker.
     * @param node The ID of the node.
     */
    event StakedToNewNode(address indexed sender, NodeId indexed node);
    /**
     * @notice Emitted when a user stops staking to a node
     * @param sender The address of the staker.
     * @param node The ID of the node.
     */
    event StoppedStaking(address indexed sender, NodeId indexed node);
    /**
     * @notice Emitted when a node's data is removed
     * @param node The ID of the node.
     */
    event NodeDataRemoved(NodeId indexed node);
    /**
     * @notice Emitted when a node is disabled
     * @param node The ID of the node.
     */
    event NodeDisabled(NodeId indexed node);
    /**
     * @notice Emitted when a node is enabled
     * @param node The ID of the node.
     */
    event NodeEnabled(NodeId indexed node);
    /**
     * @notice Emitted when the retrieving delay is updated
     * @param retrievingDelay The new retrieving delay.
     */
    event RetrievingDelayUpdated(Timestamp indexed retrievingDelay);
    /**
     * @notice Emitted when the stake limit is updated
     * @param newLimit The new stake limit.
     */
    event StakeLimitUpdated(Fair indexed newLimit);
    /**
     * @notice Emitted when a node's fee rate is updated
     * @param node The ID of the node.
     * @param oldFeeRate The old fee rate.
     * @param newFeeRate The new fee rate.
     */
    event NodeFeeRateUpdated(NodeId indexed node, uint16 oldFeeRate, uint16 newFeeRate);
    /**
     * @notice Emitted when the reward wallet reference is updated
     * @param oldReference The old reward wallet reference.
     * @param newReference The new reward wallet reference.
     */
    event RewardWalletReferenceUpdated(IRewardWallet indexed oldReference, IRewardWallet indexed newReference);
    /**
     * @notice Emitted when the self-stake requirement is updated
     * @param amount The new self-stake requirement.
     */
    event SelfStakeRequirementUpdated(Fair indexed amount);
    /**
     * @notice Emitted when self-stake is provided for a node
     * @param nodeId The ID of the node.
     * @param amount The amount of self-stake provided.
     */
    event SelfStakeProvided(NodeId indexed nodeId, Fair amount);

    error FeeRateIsIncorrect(uint16 feeRate);
    error OnlyFeeReductionIsAllowed(uint16 currentRate, uint16 newRate);
    error ZeroAmount();
    error ZeroStakeToNode(NodeId node);
    error NodeIsAlreadyDisabled(NodeId node);
    error NodeIsNotDisabled(NodeId node);
    error NotAllowedToClaimRewards(address sender);
    error StakeLimitExceeded(Fair currentStake, Fair attemptedStake, Fair limit);
    error ReceiverIsAlreadyAllowed(address receiver);
    error ReceiverWasNotAllowed(address receiver);
    error RewardWalletDoesNotExist(NodeId node);
    error NodeOwnerCannotRetrieveWhileNodeExists(address nodeOwner, NodeId node);
    error InsufficientSelfStake(Fair provided, Fair required);

    modifier onlyExistingActiveNode(NodeId node) {
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
        _;
    }

    /// @notice Receives ether and emits a RewardReceived event
    receive() external payable override {
        emit RewardReceived(msg.sender, msg.value);
    }

    /**
     * @notice Initializes the Staking contract
     * @param initialAuthority The address of the initial authority
     * @param committee_ The address of the committee contract
     * @param nodes_ The address of the nodes contract
     * @param rewardWalletReference_ The address of the reward wallet reference
     */
    function initialize(
        address initialAuthority,
        ICommittee committee_,
        INodes nodes_,
        IRewardWallet rewardWalletReference_
    )
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        __ReentrancyGuard_init();
        committee = committee_;
        nodes = nodes_;
        rewardWalletReference = rewardWalletReference_;
        // Default on initialize
        _exitQueue.retrievingDelay = Timestamp.wrap(1 days);
        selfStakeRequirement = Fair.wrap(1);
        emit RetrievingDelayUpdated(Timestamp.wrap(1 days));
    }

    /**
     * @notice Adds an allowed receiver of Fees for a Node
     * @param receiver The address of the receiver to add
     */
    function addAllowedReceiver(address receiver) external override {
        NodeId node = nodes.getNodeId(msg.sender);
        bool added = _nodesAllowedReceivers[node].add(receiver);
        require(added, ReceiverIsAlreadyAllowed(receiver));
        emit AllowedReceiverAdded(node, receiver);
    }

    /**
     * @notice Removes an allowed receiver of Fees for a Node
     * @param receiver The address of the receiver to remove
     */
    function removeAllowedReceiver(address receiver) external override {
        NodeId node = nodes.getNodeId(msg.sender);
        bool removed = _nodesAllowedReceivers[node].remove(receiver);
        require(removed, ReceiverWasNotAllowed(receiver));
        emit AllowedReceiverRemoved(node, receiver);
    }

    /**
     * @notice Requests all fees for a node
     * @param node The ID of the node
     */
    function requestAllFees(NodeId node) external override {
        requestFees(node, getEarnedFeeAmount(node));
    }

    /**
     * @notice Requests to send all fees to a specific address
     * @param to The address to send the fees to
     */
    function requestSendAllFees(address payable to) external override {
        requestSendFees(to, getEarnedFeeAmount(nodes.getNodeId(msg.sender)));
    }

    /**
     * @notice Sets the minimum self-stake requirement
     * @param amount The new self-stake requirement
     */
    function setSelfStakeRequirement(Fair amount) external override restricted {
        selfStakeRequirement = amount;
        emit SelfStakeRequirementUpdated(amount);
    }

    /**
     * @notice Disables a node (callable by Committee)
     * @param node The ID of the node to disable
     */
    function disable(NodeId node) external override restricted {
        Fair balance = _getTotalBalance();
        Fair nodeFundBalance = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
        _rootFund.remove(balance, FundLibrary.nodeToHolder(node), nodeFundBalance);
        totalDisabled = totalDisabled + nodeFundBalance;
        require(_disabledNodesBalances.set(node, nodeFundBalance), NodeIsAlreadyDisabled(node));
        emit NodeDisabled(node);

        assert(_getNodeCredits(node) == FundLibrary.ZERO_CREDIT);
        assert(_rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)) == FundLibrary.ZERO_FAIR);

        if (nodes.activeNodeExists(node)) {
            committee.updateWeight(node, 0);
        }
    }

    /**
     * @notice Enables a node (callable by Committee)
     * @param node The ID of the node to enable
     */
    function enable(NodeId node) external override restricted onlyExistingActiveNode(node) {
        _pullReward(node);
        (bool wasDisabled, Fair value) = _disabledNodesBalances.tryGet(node);
        require(wasDisabled, NodeIsNotDisabled(node));
        Fair balance = _getTotalBalance();
        _rootFund.supply(balance, FundLibrary.nodeToHolder(node), value);
        assert(_disabledNodesBalances.remove(node));
        totalDisabled = totalDisabled - value;

        // Node might have changed it's balance due to rounding in supply()
        // Force update on nodeFund
        Fair finalBalance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node));
        if (!(finalBalance == value)) {
            _nodesFunds[node].updateTotalBalance(
                _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node))
            );
        }

        emit NodeEnabled(node);
    }

    /**
     * @notice Handles the creation of a new node (callable by Nodes)
     * @param node The ID of the node
     * @param nodeAddress The address of the node
     */
    function nodeCreated(NodeId node, address nodeAddress) external payable override restricted {
        if (_rewardWallets[node] == IRewardWallet(payable(0))) {
            _deployRewardWallet(node);
        }

        // Node should be set as disabled with 0 stake before anything
        // SelfStake will be added (If any) while node is disabled
        assert(_disabledNodesBalances.set(node, FundLibrary.ZERO_FAIR));

        _updateNodeFeeRate(node, DEFAULT_FEE_RATE);
        _checkProvidedSelfStake(node);
        if (msg.value > 0) {
            _stakeFor(node, nodeAddress);
        }
    }

    /**
     * @notice Handles the removal of a node (callable by Nodes)
     * @param node The ID of the node to remove
     */
    function nodeRemoved(NodeId node) external override restricted {
        // Committee should disable node first
        require(!isNodeEnabled(node), NodeIsNotDisabled(node));
        _nodesAllowedReceivers[node].clear();
        delete _nodesAllowedReceivers[node];
        // Don't delete reward wallet,
        // because it's needed for archive node synchronization
        emit NodeDataRemoved(node);

        address nodeOwner = _publicKeyToAddress(nodes.getPublicKey(node));
        Fair fees = getEarnedFeeAmount(node);
        Fair nodeOwnerStake = getStakedToNodeAmountFor(node, nodeOwner);
        Fair amountToRetrieve = FundLibrary.ZERO_FAIR;

        if (nodeOwnerStake > FundLibrary.ZERO_FAIR) {
            _retrieveFundsFor(node, nodeOwnerStake, nodeOwner);
            amountToRetrieve = amountToRetrieve + nodeOwnerStake;
        }

        if (fees > FundLibrary.ZERO_FAIR) {
            _requestSendFees(node, fees, payable(nodeOwner));
            amountToRetrieve = amountToRetrieve + fees;
        }
        _exitQueue.createRequest(nodeOwner, node, amountToRetrieve);
    }

    /**
     * @notice Pays a reward to a node and its stakers
     * @param node The ID of the node
     */
    function payReward(NodeId node) external payable override onlyExistingActiveNode(node) {
        require(msg.value > 0, ZeroAmount());
        bool nodeIsEnabled = !_disabledNodesBalances.contains(node);
        Fair amount = Fair.wrap(msg.value);
        Fair balance = _getTotalBalance() - amount;
        (bool withinStakeLimit, Fair currentNodeStake) = _isWithinStakeLimit(node, amount);

        // allow to payRewards over the limit only for reward wallet
        require(
            withinStakeLimit || msg.sender == address(_rewardWallets[node]),
            StakeLimitExceeded(currentNodeStake, amount, stakeLimit)
        );

        if (nodeIsEnabled) {
            _rootFund.supply(balance, FundLibrary.nodeToHolder(node), amount);
        } else {
            assert(!_disabledNodesBalances.set(node, _disabledNodesBalances.get(node) + amount));
            totalDisabled = totalDisabled + amount;
        }
        emit NodeRewardReceived(node, amount);

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_rootFund.credits.get(FundLibrary.nodeToHolder(node))));
        }
    }

    /**
     * @notice Claims an exit request
     * @param requestId The ID of the exit request
     */
    function claimRequest(uint256 requestId) external override nonReentrant {
        Fair amount = _exitQueue.claim(msg.sender, requestId);
        payable(msg.sender).sendValue(Fair.unwrap(amount));
    }

    /**
     * @notice Sets the stake limit for each Node
     * @param limit The new stake limit
     */
    function setStakeLimit(Fair limit) external override restricted {
        emit StakeLimitUpdated(limit);
        stakeLimit = limit;
    }

    /**
     * @notice Sets the retrieving delay of a request
     * @param delay The new retrieving delay
     */
    function setRetrievingDelay(Timestamp delay) external override restricted {
        _exitQueue.retrievingDelay = delay;
        emit RetrievingDelayUpdated(delay);
    }

    /**
     * @notice Sets the fee rate for a node
     * @param feeRate The new fee rate
     */
    function setFeeRate(uint16 feeRate) external override {
        require(!(feeRate > 1000), FeeRateIsIncorrect(feeRate));
        NodeId node = nodes.getNodeId(msg.sender);
        uint16 currentFeeRate = _nodesFunds[node].feeRate;
        require(
            _nodesFunds[node].totalCredits == FundLibrary.ZERO_CREDIT || feeRate < currentFeeRate,
            OnlyFeeReductionIsAllowed(currentFeeRate, feeRate)
        );
        _pullReward(node);

        emit NodeFeeRateUpdated(node, currentFeeRate, feeRate);
        _updateNodeFeeRate(node, feeRate);
    }

    /**
     * @notice Sets the reward wallet implementation reference
     * @param rewardWalletReference_ The new reward wallet reference
     */
    function setRewardWalletReference(IRewardWallet rewardWalletReference_) external override restricted {
        emit RewardWalletReferenceUpdated(rewardWalletReference, rewardWalletReference_);
        rewardWalletReference = rewardWalletReference_;
    }

    /**
     * @notice Allows sender to retrieve all staked tokens for a node
     * @param node The ID of the node
     */
    function requestRetrieveAll(NodeId node) external override {
        requestRetrieve(node, getStakedToNodeAmountFor(node, msg.sender));
    }

    /**
     * @notice Stakes funds to a node
     * @param node The ID of the node
     */
    function stake(NodeId node) external payable override onlyExistingActiveNode(node) {
        _stakeFor(node, msg.sender);
    }

    /**
     * @notice Gets number of shares for a node
     * @param node The ID of the node
     * @return share The share of the node
     */
    function getNodeShare(NodeId node) external view override returns (uint256 share) {
        if (!isNodeEnabled(node)) {
            return 0;
        }
        Fair totalBalance = _getTotalBalance();
        uint256 unPulledCredits = 0;
        uint256 rewardWalletBalance = address(_rewardWallets[node]).balance;
        if (rewardWalletBalance > 0) {
            if (totalBalance > FundLibrary.ZERO_FAIR) {
                unPulledCredits = Math.mulDiv(
                    rewardWalletBalance,
                    Credit.unwrap(_rootFund.totalCredits),
                    Fair.unwrap(totalBalance),
                    Math.Rounding.Floor
                );
            } else {
                unPulledCredits = rewardWalletBalance * FundLibrary.CREDIT_PRECISION;
            }
        }
        return Credit.unwrap(_getNodeCredits(node)) + unPulledCredits;
    }

    /**
     * @notice Gets the reward wallet address of a node
     * @param node The ID of the node
     * @return rewardWallet The reward wallet of the node
     */
    function getRewardWallet(NodeId node) external view override returns (IRewardWallet rewardWallet) {
        rewardWallet = _rewardWallets[node];
        require(rewardWallet != IRewardWallet(payable(0)), RewardWalletDoesNotExist(node));
    }

    /**
     * @notice Gets the total staked amount for the sender
     * @return amount The total staked amount
     */
    function getStakedAmount() external view override returns (Fair amount) {
        return getStakedAmountFor(msg.sender);
    }

    /**
     * @notice Gets the sender's staked amount for a specific node
     * @param node The ID of the node
     * @return amount The staked amount for the node
     */
    function getStakedToNodeAmount(NodeId node) external view override returns (Fair amount) {
        return getStakedToNodeAmountFor(node, msg.sender);
    }

    /**
     * @notice Gets the list of nodes the sender has staked to
     * @return stakedNodes The list of staked nodes
     */
    function getStakedNodes() external view override returns (NodeId[] memory stakedNodes) {
        return getStakedNodesFor(msg.sender);
    }

    /**
     * @notice Gets the total stake of a specific node
     * @param node The ID of the node
     * @return amount The total stake of the node
     */
    function getNodeTotalStake(NodeId node) external view override returns (Fair amount) {
        return _getNodeTotalStakeBeforeAmount(node, FundLibrary.ZERO_FAIR);
    }

    /**
     * @notice Gets the fee rate of a specific node
     * @param node The ID of the node
     * @return feeRate The fee rate of the node
     */
    function getNodeFeeRate(NodeId node) external view override returns (uint16 feeRate) {
        return _nodesFunds[node].feeRate;
    }

    /**
     * @notice Gets the list of delegators for a specific node
     * @param node The ID of the node
     * @return delegators The list of delegators
     */
    function getDelegatorsToNode(NodeId node) external view override returns (address[] memory delegators) {
        Holder[] memory holders = _nodesFunds[node].credits.keys();
        delegators = new address[](holders.length);
        uint256 loops = holders.length;
        for (uint256 i = 0; i < loops; ++i) {
            delegators[i] = FundLibrary.holderToAddress(holders[i]);
        }
    }

    /**
     * @notice Gets the count of delegators for a specific node
     * @param node The ID of the node
     * @return count The count of delegators
     */
    function getDelegatorsToNodeCount(NodeId node) external view override returns (uint256 count) {
        count = _nodesFunds[node].credits.length();
    }

    /**
     * @notice Gets the count of exit requests for a user
     * @param user The address of the user
     * @return count The count of exit requests
     */
    function getExitRequestsCountFor(address user) external view override returns (uint256 count) {
        return _exitQueue.getNumRequestsForUser(user);
    }

    /**
     * @notice Gets the total amount in the exit queue for the sender
     * @return amount The total amount in the exit queue
     */
    function getMyTotalInExitQueue() external view override returns (Fair amount) {
        return _exitQueue.getTotalInQueueForUser(msg.sender);
    }

    /**
     * @notice Gets the count of exit requests for the sender
     * @return count The count of exit requests
     */
    function getMyExitRequestsCount() external view override returns (uint256 count) {
        return _exitQueue.getNumRequestsForUser(msg.sender);
    }

    /**
     * @notice Checks if a node is within the stake limit
     * @param node The ID of the node
     * @return result True if within the stake limit, false otherwise
     */
    function isWithinStakeLimit(NodeId node) external view override returns (bool result) {
        (result,) = _isWithinStakeLimit(node, FundLibrary.ZERO_FAIR);
    }

    /**
     * @notice Gets an exit request by its ID
     * @param requestId The ID of the exit request
     * @return request The exit request
     */
    function getExitRequest(uint256 requestId) external view override returns (ExitRequest memory request) {
        request = _exitQueue.getRequest(requestId);
    }

    /**
     * @notice Gets an unlocked exit request for a user starting from a specific index
     * @param user The address of the user
     * @param fromIndex The starting index to lookup from
     * @return request The unlocked exit request
     */
    function getUnlockedExitRequestFor(
        address user,
        uint256 fromIndex
    )
        external
        view
        override
        returns (ExitRequest memory request)
    {
        return _exitQueue.getUnlockedRequest(user, fromIndex);
    }

    /**
     * @notice Gets an exit request at a specific index for a user
     * @param user The address of the user
     * @param index The index of the exit request
     * @return request The exit request
     */
    function getExitRequestAt(
        address user,
        uint256 index
    )
        external
        view
        override
        returns (ExitRequest memory request)
    {
        request = _exitQueue.getRequestAt(user, index);
    }

    /**
     * @notice Checks if an exit request is unlocked
     * @param requestId The ID of the exit request
     * @return unlocked True if the request is unlocked, false otherwise
     */
    function isRequestUnlocked(uint256 requestId) external view override returns (bool unlocked) {
        return _exitQueue.isRequestUnlocked(requestId);
    }

    /**
     * @notice Gets the currently active retrieving delay for exit requests
     * @return delay The retrieving delay
     */
    function getRetrievingDelay() external view override returns (Timestamp delay) {
        return _exitQueue.retrievingDelay;
    }

    /**
     * @notice Gets the total amount in the exit queue for a user
     * @param user The address of the user
     * @return amount The total amount in the exit queue
     */
    function getTotalInExitQueueFor(address user) external view override returns (Fair amount) {
        return _exitQueue.getTotalInQueueForUser(user);
    }

    // Public

    /**
     * @notice Allows user to unstake from a specific node (creates an exit request)
     * @param node The ID of the node
     * @param value The amount of funds to retrieve
     */
    function requestRetrieve(NodeId node, Fair value) public override {
        // Private helper does all internal state changes and verifications
        (bool nodeIsEnabled) = _retrieveFunds(node, value);
        _exitQueue.createRequest(msg.sender, node, value);

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

    /**
     * @notice Claims fees from a specific node (creates an exit request)
     * @param node The ID of the node
     * @param amount The amount of fees to request
     */
    function requestFees(NodeId node, Fair amount) public override onlyExistingActiveNode(node) {
        require(amount > FundLibrary.ZERO_FAIR, ZeroAmount());
        bool senderIsOwner = msg.sender == nodes.getNode(node).nodeAddress;
        require(
            _nodesAllowedReceivers[node].contains(msg.sender) || senderIsOwner, NotAllowedToClaimRewards(msg.sender)
        );
        _requestSendFees(node, amount, payable(msg.sender));
        _exitQueue.createRequest(payable(msg.sender), node, amount);
    }

    /**
     * @notice Requests to send fees to a specific address (creates an exit request for 'to' that needs to be claimed)
     * @param to The address to send the fees to
     * @param amount The amount of fees to send
     */
    function requestSendFees(address payable to, Fair amount) public override {
        require(amount > FundLibrary.ZERO_FAIR, ZeroAmount());
        NodeId node = nodes.getNodeId(msg.sender);

        // Node has opted in to allowed receivers, so the destination address must be in the list
        // Or be the owner
        if (_hasAllowedReceiver(node)) {
            require(_nodesAllowedReceivers[node].contains(to) || to == msg.sender, NotAllowedToClaimRewards(to));
        }
        _requestSendFees(node, amount, to);
        _exitQueue.createRequest(to, node, amount);
    }

    /**
     * @notice Checks if a node is enabled
     * @param node The ID of the node
     * @return enabled True if the node is enabled, false otherwise
     */
    function isNodeEnabled(NodeId node) public view override returns (bool enabled) {
        return !_disabledNodesBalances.contains(node);
    }

    /**
     * @notice Gets the earned fee amount for a specific node
     * @param node The ID of the node
     * @return amount The earned fee amount
     */
    function getEarnedFeeAmount(NodeId node) public view override returns (Fair amount) {
        Fair nonPulledReward = _getNonPulledReward(node);
        if (!isNodeEnabled(node)) {
            return _nodesFunds[node].getEarnedFee(_disabledNodesBalances.get(node) + nonPulledReward);
        }
        return _nodesFunds[node].getEarnedFee(
            _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)) + nonPulledReward
        );
    }

    /**
     * @notice Gets the total staked amount for a specific holder
     * @param holder The address of the holder
     * @return amount The total staked amount
     */
    function getStakedAmountFor(address holder) public view override returns (Fair amount) {
        uint256 nodesCount = _stakedNodes[holder].length();
        for (uint256 nodeIndex; nodeIndex < nodesCount; ++nodeIndex) {
            NodeId node = _stakedNodes[holder].at(nodeIndex);
            amount = amount + getStakedToNodeAmountFor(node, holder);
        }
    }

    /**
     * @notice Gets the list of nodes a holder has staked to
     * @param holder The address of the holder
     * @return stakedNodes The list of staked nodes
     */
    function getStakedNodesFor(address holder) public view override returns (NodeId[] memory stakedNodes) {
        return _stakedNodes[holder].values();
    }

    /**
     * @notice Gets the staked amount for a specific node and holder
     * @param node The ID of the node
     * @param holder The address of the holder
     * @return amount The staked amount
     */
    function getStakedToNodeAmountFor(NodeId node, address holder) public view override returns (Fair amount) {
        Fair nodeBalance;
        Fair nonPulledReward = _getNonPulledReward(node);
        if (!isNodeEnabled(node)) {
            nodeBalance = _disabledNodesBalances.get(node) + nonPulledReward;
        } else {
            nodeBalance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)) + nonPulledReward;
        }
        return _nodesFunds[node].getBalance(nodeBalance, FundLibrary.addressToHolder(holder));
    }

    /**
     * @notice Gets the total amount of funds in the Staking exit queue
     * @return amount The total amount in the exit queue
     */
    function getTotalInExitQueue() public view override returns (Fair amount) {
        return _exitQueue.totalInExitQueue;
    }

    // Private

    /**
     * @notice Stakes funds for a specific staker to a node.
     * @param node The ID of the node to stake to.
     * @param staker The address of the staker.
     */
    function _stakeFor(NodeId node, address staker) private {
        require(msg.value > 0, ZeroAmount());
        bool nodeIsEnabled = isNodeEnabled(node);
        Fair amount = Fair.wrap(msg.value);
        emit Staked(staker, node, amount);
        _pullReward(node);
        Fair balance = _getTotalBalance() - amount;

        _validateStakeLimit(node, amount);

        if (nodeIsEnabled) {
            _nodesFunds[node].supply(
                _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
                FundLibrary.addressToHolder(staker),
                amount
            );
            _rootFund.supply(balance, FundLibrary.nodeToHolder(node), amount);
        } else {
            Fair nodeFundBalance = _disabledNodesBalances.get(node);
            _nodesFunds[node].supply(nodeFundBalance, FundLibrary.addressToHolder(staker), amount);
            assert(!_disabledNodesBalances.set(node, nodeFundBalance + amount));
            totalDisabled = totalDisabled + amount;
        }
        if (_stakedNodes[staker].add(node)) {
            emit StakedToNewNode(staker, node);
        }

        if (nodeIsEnabled) {
            // Reward Wallet already flushed
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

    /**
     * @notice Requests to send fees to a specific address.
     * @param node The ID of the node.
     * @param amount The amount of fees to send.
     * @param to The address to send the fees to.
     */
    function _requestSendFees(NodeId node, Fair amount, address to) private {
        // sender can be allowed user, nodeOwner, or Nodes.sol contract (node deleted)
        emit FeeClaimRequested(node, msg.sender, to, amount);
        _pullReward(node);
        Fair balance = _getTotalBalance();
        bool nodeIsEnabled = isNodeEnabled(node);
        if (nodeIsEnabled) {
            _nodesFunds[node].claimFee(_rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)), amount);
            _rootFund.remove(balance, FundLibrary.nodeToHolder(node), amount);
        } else {
            Fair nodeBalance = _disabledNodesBalances.get(node);
            _nodesFunds[node].claimFee(nodeBalance, amount);
            // node is already disabled, should return false
            assert(!_disabledNodesBalances.set(node, nodeBalance - amount));
            totalDisabled = totalDisabled - amount;
        }

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

    /**
     * @notice Retrieves funds for a specific staker from a node.
     * @param node The ID of the node.
     * @param value The amount of funds to retrieve.
     * @param staker The address of the staker.
     * @return nodeIsEnabled True if the node is enabled, false otherwise.
     */
    function _retrieveFundsFor(NodeId node, Fair value, address staker) private returns (bool nodeIsEnabled) {
        require(value > FundLibrary.ZERO_FAIR, ZeroAmount());
        require(_stakedNodes[staker].contains(node), ZeroStakeToNode(node));

        _checkNodeOwnerRestriction(staker, node);

        emit RetrieveRequested(staker, node, value);
        _pullReward(node);
        nodeIsEnabled = isNodeEnabled(node);

        if (nodeIsEnabled) {
            Fair balance = _getTotalBalance();
            _nodesFunds[node].remove(
                _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
                FundLibrary.addressToHolder(staker),
                value
            );
            _rootFund.remove(balance, FundLibrary.nodeToHolder(node), value);
        } else {
            Fair nodeFundBalance = _disabledNodesBalances.get(node);
            _nodesFunds[node].remove(nodeFundBalance, FundLibrary.addressToHolder(staker), value);
            assert(!_disabledNodesBalances.set(node, nodeFundBalance - value));
            totalDisabled = totalDisabled - value;
        }
        (bool exists, Credit holderCredits) = _nodesFunds[node].credits.tryGet(FundLibrary.addressToHolder(staker));
        if (holderCredits == FundLibrary.ZERO_CREDIT) {
            assert(_stakedNodes[staker].remove(node) && !exists);
            emit StoppedStaking(staker, node);
        }
    }

    /**
     * @notice Retrieves funds for the message sender from a node.
     * @param node The ID of the node.
     * @param value The amount of funds to retrieve.
     * @return nodeIsEnabled True if the node is enabled, false otherwise.
     */
    function _retrieveFunds(NodeId node, Fair value) private returns (bool nodeIsEnabled) {
        return _retrieveFundsFor(node, value, msg.sender);
    }

    /**
     * @notice Deploys a new reward wallet for a node.
     * @param node The ID of the node.
     */
    function _deployRewardWallet(NodeId node) private {
        ProxyAdmin proxyAdmin = ProxyAdmin(ERC1967Utils.getAdmin());
        emit RewardWalletCreated(node);
        _rewardWallets[node] = IRewardWallet(
            payable(
                new TransparentUpgradeableProxy(
                    address(rewardWalletReference),
                    proxyAdmin.owner(),
                    abi.encodeWithSelector(
                        IRewardWallet.initialize.selector, authority(), IStaking(payable(this)), nodes, node
                    )
                )
            )
        );
    }

    /**
     * @notice Pulls rewards from a node's reward wallet.
     * @param node The ID of the node.
     */
    function _pullReward(NodeId node) private nonReentrant {
        // safe because getNonPulledReward returns 0 if rewardWallet does not exist
        if (_getNonPulledReward(node) > FundLibrary.ZERO_FAIR) {
            // Reward wallet is considered as a part of Staking contract.
            // The code is trusted and effects are known.
            // slither-disable-start reentrancy-events
            // slither-disable-next-line reentrancy-benign
            _rewardWallets[node].flush();
            // slither-disable-end reentrancy-events
        }
    }

    /**
     * @notice Updates the fee rate for a node.
     * @param node The ID of the node.
     * @param feeRate The new fee rate.
     */
    function _updateNodeFeeRate(NodeId node, uint16 feeRate) private {
        Fair balance;
        if (isNodeEnabled(node)) {
            balance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node));
        } else {
            balance = _disabledNodesBalances.get(node);
        }
        _nodesFunds[node].setFeeRate(balance, feeRate);
    }

    /**
     * @notice Checks if msg.value meets the minimum self-stake requirement.
     * @param nodeId The ID of the node.
     */
    function _checkProvidedSelfStake(NodeId nodeId) private {
        Fair providedStake = Fair.wrap(msg.value);
        require(!(selfStakeRequirement > providedStake), InsufficientSelfStake(providedStake, selfStakeRequirement));
        emit SelfStakeProvided(nodeId, providedStake);
    }

    /**
     * @notice Gets the credits of a node.
     * @param node The ID of the node.
     * @return credits The credits of the node.
     */
    function _getNodeCredits(NodeId node) private view returns (Credit credits) {
        (bool exists, Credit amount) = _rootFund.credits.tryGet(FundLibrary.nodeToHolder(node));
        credits = amount;
        // If exists credits is not 0, otherwise it is 0.
        assert(exists != (credits == FundLibrary.ZERO_CREDIT));
    }

    /**
     * @notice Gets the total stake of a node before a certain amount is added.
     * @param node The ID of the node.
     * @param amount The amount to be added.
     * @return total The total stake of the node.
     */
    function _getNodeTotalStakeBeforeAmount(NodeId node, Fair amount) private view returns (Fair total) {
        if (isNodeEnabled(node)) {
            Fair balance = _getTotalBalance() - amount;
            total = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
        } else {
            total = _disabledNodesBalances.get(node);
        }
        total = total + _getNonPulledReward(node);
    }

    /**
     * @notice Gets the non-pulled reward for a node.
     * @param node The ID of the node.
     * @return nonPulledReward The non-pulled reward.
     */
    function _getNonPulledReward(NodeId node) private view returns (Fair nonPulledReward) {
        if (_rewardWallets[node] == IRewardWallet(payable(0))) {
            return FundLibrary.ZERO_FAIR;
        }
        return Fair.wrap(address(_rewardWallets[node]).balance);
    }

    /**
     * @notice Gets the total stake of enabled nodes in the contract.
     * @return balance The total stake.
     */
    function _getTotalBalance() private view returns (Fair balance) {
        return Fair.wrap(address(this).balance) - totalDisabled - getTotalInExitQueue();
    }

    /**
     * @notice Checks if a node is within the stake limit.
     * @param node The ID of the node.
     * @param amount The extra amount to check.
     * @return result True if the node's stake + amount is within the stake limit, false otherwise.
     * @return currentNodeStake The current stake of the node (before amount).
     */
    function _isWithinStakeLimit(NodeId node, Fair amount) private view returns (bool result, Fair currentNodeStake) {
        result = true;
        if (stakeLimit > FundLibrary.ZERO_FAIR) {
            currentNodeStake = _getNodeTotalStakeBeforeAmount(node, amount);
            Fair newNodeStake = currentNodeStake + amount;
            result = !(newNodeStake > stakeLimit);
        }
    }

    /**
     * @notice Validates if an extra amount results in exceeding the stake limit.
     * @param node The ID of the node.
     * @param amount The extra amount to be staked.
     */
    function _validateStakeLimit(NodeId node, Fair amount) private view {
        (bool isWithinLimit, Fair currentNodeStake) = _isWithinStakeLimit(node, amount);
        require(isWithinLimit, StakeLimitExceeded(currentNodeStake, amount, stakeLimit));
    }

    /**
     * @notice Checks if a node has any allowed receivers for fees.
     * @param node The ID of the node.
     * @return result True if the node has allowed receivers, false otherwise.
     */
    function _hasAllowedReceiver(NodeId node) private view returns (bool result) {
        return _nodesAllowedReceivers[node].length() > 0;
    }

    /**
     * @notice Checks if the sender is the node owner, for non-deleted active nodes.
     * @param sender The address of the message sender.
     * @param node The ID of the node.
     */
    function _checkNodeOwnerRestriction(address sender, NodeId node) private view {
        if (nodes.activeNodeExists(node)) {
            address nodeOwner = nodes.getNode(node).nodeAddress;
            require(sender != nodeOwner, NodeOwnerCannotRetrieveWhileNodeExists(sender, node));
        }
    }

    /**
     * @notice Converts a public key to an Ethereum address.
     * @param pubKey The public key to convert.
     * @return nodeAddress The resulting Ethereum address.
     */
    function _publicKeyToAddress(bytes32[2] memory pubKey) private pure returns (address nodeAddress) {
        bytes32 hash = keccak256(abi.encodePacked(pubKey[0], pubKey[1]));
        return address(uint160(uint256(hash)));
    }

}
