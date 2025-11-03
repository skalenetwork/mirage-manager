// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Staking.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *
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

// OpenZeppelin imports
import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { IBeacon } from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// External interfaces
import { ICommittee } from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IRewardWallet } from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";

// Internal project files
import { TypedMap } from "./structs/typed/TypedMap.sol";
import { TypedSet } from "./structs/typed/TypedSet.sol";
import { DEFAULT_MIN_STAKE, DEFAULT_RETRIEVING_DELAY } from "./utils/constants.sol";
import { InvalidCommitteeAddress, InvalidNodesAddress, NodeDoesNotExist } from "./utils/errors.sol";
import { ExitQueueLibrary, Timestamp } from "./utils/ExitQueue.sol";
import { Credit, FundLibrary, Fair, Holder } from "./utils/Fund.sol";

/**
 * @title Staking
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 *
 * @notice Manages staking operations for FAIR network nodes
 * @dev Implements a two-level fund structure with reward distribution, fee collection, and exit-queue management
 */
contract Staking is AccessManagedUpgradeable, ReentrancyGuardUpgradeable, IStaking {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using FundLibrary for FundLibrary.Fund;
    using TypedSet for TypedSet.NodeIdSet;
    using TypedMap for TypedMap.HolderToCreditMap;
    using TypedMap for TypedMap.NodeIdToFairMap;
    using ExitQueueLibrary for ExitQueueLibrary.ExitQueue;

    /// @notice Default fee rate starting value (100% of precision; maximum possible fee rate)
    uint16 public constant DEFAULT_FEE_RATE = FundLibrary.FEE_RATE_PRECISION;

    /// @notice Reference to the Committee contract
    ICommittee public committee;

    /// @notice Reference to the Nodes contract
    INodes public nodes;

    /// @notice Reference to the reward wallet beacon contract
    IBeacon public rewardWalletBeacon;

    /// @notice Total amount of funds in disabled nodes
    Fair public totalDisabled;

    /// @notice Maximum stake allowed per node
    Fair public stakeLimit;

    /// @notice Minimum self-stake required from node owners
    Fair public selfStakeRequirement;

    /// @dev Root fund managing all active & not disabled node stakes
    FundLibrary.Fund private _rootFund;

    /// @dev Queue for managing exit requests with time delays
    ExitQueueLibrary.ExitQueue private _exitQueue;

    /// @dev Mapping of node IDs to their individual funds
    mapping (NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;

    /// @dev Mapping of node IDs to their reward wallet contracts
    mapping (NodeId node => IRewardWallet rewardWallet) private _rewardWallets;

    /// @dev Mapping of node IDs to sets of addresses allowed to claim fees on behalf of the node
    mapping (NodeId node => EnumerableSet.AddressSet allowedReceivers) private _nodesAllowedReceivers;

    /// @dev Mapping of holder addresses to the set of nodes they have staked to
    mapping (address holder => TypedSet.NodeIdSet nodeIds) private _stakedNodes;

    /// @dev Mapping of disabled node IDs to their current balances
    TypedMap.NodeIdToFairMap private _disabledNodesBalances;

    /**
     * @notice Emitted when an address is added to a node's allowed fee receivers list
     * @param node The node ID
     * @param receiver The address added to the allowed receivers list
     */
    event AllowedReceiverAdded(NodeId indexed node, address indexed receiver);

    /**
     * @notice Emitted when an address is removed from a node's allowed receivers list
     * @param node The node ID
     * @param receiver The address removed from the allowed receivers list
     */
    event AllowedReceiverRemoved(NodeId indexed node, address indexed receiver);

    /**
     * @notice Emitted when a fee claim is requested
     * @param node The node from which fees are claimed
     * @param from The address requesting the claim
     * @param to The address to receive the fees
     * @param amount The amount of fees claimed
     */
    event FeeClaimRequested(NodeId indexed node, address from, address indexed to, Fair indexed amount);

    /**
     * @notice Emitted when a node receives a reward
     * @param node The node receiving the reward
     * @param amount The amount of the reward
     */
    event NodeRewardReceived(NodeId indexed node, Fair indexed amount);

    /**
     * @notice Emitted when a stake retrieval is requested
     * @param sender The address requesting the retrieval
     * @param node The node from which stake is being retrieved
     * @param amount The amount being retrieved
     */
    event RetrieveRequested(address indexed sender, NodeId indexed node, Fair indexed amount);

    /**
     * @notice Emitted when the contract receives a reward payment
     * @param sender The address sending the reward
     * @param amount The amount of the reward
     */
    event RewardReceived(address indexed sender, uint256 indexed amount);

    /**
     * @notice Emitted when a reward wallet is created for a node
     * @param node The node for which the reward wallet was created
     */
    event RewardWalletCreated(NodeId indexed node);

    /**
     * @notice Emitted when stake is added to a node
     * @param sender The address staking
     * @param node The node receiving the stake
     * @param amount The amount staked
     */
    event Staked(address indexed sender, NodeId indexed node, Fair indexed amount);

    /**
     * @notice Emitted when a user stakes to a new node for the first time
     * @param sender The address staking
     * @param node The new node receiving stake
     */
    event StakedToNewNode(address indexed sender, NodeId indexed node);

    /**
     * @notice Emitted when a user completely withdraws from a node
     * @param sender The address that stopped staking
     * @param node The node from which staking stopped
     */
    event StoppedStaking(address indexed sender, NodeId indexed node);

    /**
     * @notice Emitted when node data is removed from the contract
     * @param node The node whose data was removed
     */
    event NodeDataRemoved(NodeId indexed node);

    /**
     * @notice Emitted when a node is disabled
     * @param node The node that was disabled
     */
    event NodeDisabled(NodeId indexed node);

    /**
     * @notice Emitted when a node is enabled
     * @param node The node that was enabled
     */
    event NodeEnabled(NodeId indexed node);

    /**
     * @notice Emitted when the retrieving delay is updated
     * @param retrievingDelay The new retrieving delay
     */
    event RetrievingDelayUpdated(Timestamp indexed retrievingDelay);

    /**
     * @notice Emitted when the stake limit is updated
     * @param newLimit The new stake limit per node
     */
    event StakeLimitUpdated(Fair indexed newLimit);

    /**
     * @notice Emitted when a node's fee rate is updated
     * @param node The node whose fee rate was updated
     * @param oldFeeRate The previous fee rate
     * @param newFeeRate The new fee rate
     */
    event NodeFeeRateUpdated(NodeId indexed node, uint16 oldFeeRate, uint16 newFeeRate);

    /**
     * @notice Emitted when the reward wallet beacon address is updated
     * @param oldBeacon The previous beacon address
     * @param newBeacon The new beacon address
     */
    event RewardWalletBeaconUpdated(IBeacon indexed oldBeacon, IBeacon indexed newBeacon);

    /**
     * @notice Emitted when the self-stake requirement is updated
     * @param amount The new self-stake requirement
     */
    event SelfStakeRequirementUpdated(Fair indexed amount);

    /**
     * @notice Emitted when a node owner provides self-stake
     * @param nodeId The node receiving self-stake
     * @param amount The amount of self-stake provided
     */
    event SelfStakeProvided(NodeId indexed nodeId, Fair amount);

    /**
     * @notice Thrown when the provided fee rate exceeds the maximum allowed
     * @param feeRate The invalid fee rate that was provided
     */
    error FeeRateIsIncorrect(uint16 feeRate);

    /**
     * @notice Thrown when attempting to increase the fee rate of nodes with stake (only reductions are allowed)
     * @param currentRate The current fee rate
     * @param newRate The attempted new fee rate
     */
    error OnlyFeeReductionIsAllowed(uint16 currentRate, uint16 newRate);

    /**
     * @notice Thrown when an operation requires a non-zero amount but zero was provided
     */
    error ZeroAmount();

    /**
     * @notice Thrown when attempting to retrieve from a node where sender has zero stake
     * @param node The node attempted to retrieve from
     */
    error ZeroStakeToNode(NodeId node);

    /**
     * @notice Thrown when attempting to disable an already disabled node
     * @param node The node that is already disabled
     */
    error NodeIsAlreadyDisabled(NodeId node);

    /**
     * @notice Thrown when attempting an operation that requires an enabled node
     * @param node The node that is not disabled
     */
    error NodeIsNotDisabled(NodeId node);

    /**
     * @notice Thrown when an unauthorized address attempts to claim rewards
     * @param sender The unauthorized address
     */
    error NotAllowedToClaimRewards(address sender);

    /**
     * @notice Thrown when staking/payRewards would exceed the per-node stake limit
     * @param currentStake The current stake on the node
     * @param attemptedStake The amount attempting to be staked
     * @param limit The configured stake limit
     */
    error StakeLimitExceeded(Fair currentStake, Fair attemptedStake, Fair limit);

    /**
     * @notice Thrown when attempting to add an already allowed receiver
     * @param receiver The receiver that is already allowed
     */
    error ReceiverIsAlreadyAllowed(address receiver);

    /**
     * @notice Thrown when attempting to remove a receiver that was not in the list of allowed receivers
     * @param receiver The receiver that was not in the allowed list
     */
    error ReceiverWasNotAllowed(address receiver);

    /**
     * @notice Thrown when a Node does not have an associated reward wallet
     * @param node The node whose reward wallet doesn't exist
     */
    error RewardWalletDoesNotExist(NodeId node);

    /**
     * @notice Thrown when a node owner attempts to retrieve stake while their node exists
     * @param nodeOwner The address of the node owner
     * @param node The existing node
     */
    error NodeOwnerCannotRetrieveWhileNodeExists(address nodeOwner, NodeId node);

    /**
     * @notice Thrown when the provided self-stake is less than the required amount
     * @param provided The amount of self-stake provided
     * @param required The required amount of self-stake
     */
    error InsufficientSelfStake(Fair provided, Fair required);
    error InvalidRewardWalletAddress();

    /// @dev Ensures that the specified node exists and is active
    modifier onlyExistingActiveNode(NodeId node) {
        require(nodes.activeNodeExists(node), NodeDoesNotExist(node));
        _;
    }

    /**
     * @notice Fallback function to receive rewards
     * @dev Emits RewardReceived when funds are sent to the contract
     * @dev Received funds are automatically shared among all enabled nodes proportionally to stake
     */
    receive() external override payable {
        emit RewardReceived(msg.sender, msg.value);
    }

    /**
     * @notice Initializes the Staking contract
     * @dev This function is called only once during contract deployment following the proxy pattern
     * @param initialAuthority The address of the initial access control authority
     * @param committee_ The address of the Committee contract
     * @param nodes_ The address of the Nodes contract
     * @param rewardWalletBeacon_ The address of the reward wallet beacon contract
     */
    function initialize(
        address initialAuthority,
        ICommittee committee_,
        INodes nodes_,
        IBeacon rewardWalletBeacon_
    )
        external
        initializer
        override
    {
        require(address(committee_) != address(0), InvalidCommitteeAddress());
        require(address(nodes_) != address(0), InvalidNodesAddress());
        require(address(rewardWalletBeacon_) != address(0), InvalidRewardWalletAddress());
        __AccessManaged_init(initialAuthority);
        __ReentrancyGuard_init();
        committee = committee_;
        nodes = nodes_;
        rewardWalletBeacon = rewardWalletBeacon_;
        // Default on initialize
        _exitQueue.retrievingDelay = Timestamp.wrap(DEFAULT_RETRIEVING_DELAY);
        selfStakeRequirement = Fair.wrap(DEFAULT_MIN_STAKE);
        emit RetrievingDelayUpdated(Timestamp.wrap(DEFAULT_RETRIEVING_DELAY));
    }

    /**
     * @notice Updates the reward wallet beacon address
     * @dev It's a reinitializer - used once only during contract deployment or upgrade from old version
     * @param rewardWalletBeacon_ The address of the reward wallet beacon contract
     */
    function updateRewardWalletBeacon(IBeacon rewardWalletBeacon_) external reinitializer(2) restricted override{
        require(address(rewardWalletBeacon_) != address(0), InvalidRewardWalletAddress());
        IBeacon oldBeacon = rewardWalletBeacon;
        rewardWalletBeacon = rewardWalletBeacon_;
        emit RewardWalletBeaconUpdated(oldBeacon, rewardWalletBeacon_);
    }

    /**
     * @notice Adds an address to the list of allowed fee receivers for the caller's node
     * @dev Only callable by node owners
     * @param receiver The address to add to the allowed receivers list
     */
    function addAllowedReceiver(address receiver) external override {
        NodeId node = nodes.getNodeId(msg.sender);
        bool added = _nodesAllowedReceivers[node].add(receiver);
        require(added, ReceiverIsAlreadyAllowed(receiver));
        emit AllowedReceiverAdded(node, receiver);
    }

    /**
     * @notice Removes an address from the list of allowed fee receivers for the caller's node
     * @dev Only callable by node owners
     * @param receiver The address to remove from the allowed receivers list
     */
    function removeAllowedReceiver(address receiver) external override {
        NodeId node = nodes.getNodeId(msg.sender);
        bool removed = _nodesAllowedReceivers[node].remove(receiver);
        require(removed, ReceiverWasNotAllowed(receiver));
        emit AllowedReceiverRemoved(node, receiver);
    }

    /**
     * @notice Requests all earned fees for a specific node
     * @dev Only callable by node owners and allowed receivers
     * @param node The node whose fees to request
     */
    function requestAllFees(NodeId node) external override {
        requestFees(node, getEarnedFeeAmount(node));
    }

    /**
     * @notice Requests to send all earned fees to a specified address
     * @dev Only callable by node owners
     * @dev to address must be an allowed receiver if the list is not empty
     * @param to The address to receive the fees
     */
    function requestSendAllFees(address payable to) external override {
        requestSendFees(to, getEarnedFeeAmount(nodes.getNodeId(msg.sender)));
    }

    /**
     * @notice Sets the minimum self-stake requirement for nodes
     * @dev Only callable by authorized addresses (restricted)
     * @param amount The new self-stake requirement
     */
    function setSelfStakeRequirement(Fair amount) external override restricted {
        selfStakeRequirement = amount;
        emit SelfStakeRequirementUpdated(amount);
    }

    /**
     * @notice Disables a node from receiving network stability rewards
     * @dev While disabled, nodes are not eligible for committee selection (removed from root fund)
     * @dev Disabled nodes can still earn block-rewards if they are part of the current committee
     * @dev Only callable by the Committee contract (restricted)
     * @dev Ensures it's weight in committee is set to 0
     * @param node The node to disable
     */
    function disable(NodeId node) external override restricted {
        Fair balance = _getTotalBalance();
        Fair nodeFundBalance = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
        _rootFund.remove(
            balance,
            FundLibrary.nodeToHolder(node),
            nodeFundBalance
        );
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
     * @notice Enables a node to receive network stability rewards
     * @dev Only callable by Committee contract (restricted)
     * @dev Only works on existing (not deleted) active nodes
     * @dev Updates node's weight in Committee contract after enabling
     * @param node The node to enable
     */
    function enable(
        NodeId node
    )
        external
        override
        restricted
        onlyExistingActiveNode(node)
    {
        _pullReward(node);
        (bool wasDisabled, Fair value) = _disabledNodesBalances.tryGet(node);
        require(wasDisabled, NodeIsNotDisabled(node));
        Fair balance = _getTotalBalance();
        _rootFund.supply(
            balance,
            FundLibrary.nodeToHolder(node),
            value
        );
        assert(_disabledNodesBalances.remove(node));
        totalDisabled = totalDisabled - value;

        // Node might have changed its balance due to rounding in supply()
        // Force update on nodeFund
        Fair finalBalance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node));
        if(!(finalBalance == value)){
            _nodesFunds[node].updateTotalBalance(
                _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node))
            );
        }

        emit NodeEnabled(node);
    }

    /**
     * @notice Called when a new node is created
     * @dev Only callable by Nodes contract (restricted)
     * @dev Deploys a reward wallet for the new node and sets node as disabled initially
     * @dev Validates self-stake requirement and stakes all provided initial stake
     * @param node The ID of the newly created node
     * @param nodeAddress The address of the node owner
     */
    function nodeCreated(NodeId node, address nodeAddress) external payable override restricted {
        if(_rewardWallets[node] == IRewardWallet(payable(0))) {
            _deployRewardWallet(node);
        }

        // Node should be set as disabled with 0 stake before anything
        // Self-stake will be added (if any) while the node is disabled
        assert(_disabledNodesBalances.set(node, FundLibrary.ZERO_FAIR));

        _updateNodeFeeRate(node, DEFAULT_FEE_RATE);
        _checkProvidedSelfStake(node);
        if (msg.value > 0) {
            _stakeFor(node, nodeAddress);
        }
    }

    /**
     * @notice Called when a node is removed
     * @dev Only callable by Nodes contract (restricted)
     * @dev Cleans up node data and creates exit requests for node owner's stake and fees
     * @dev Node must be disabled before removal
     * @param node The ID of the node being removed
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
     * @notice Pays a reward to a node
     * @dev Only works on existing active nodes
     * @dev Enforces stake limit unless called from the node's reward wallet
     * @dev Updates committee weight if node is enabled
     * @param node The node receiving the reward
     */
    function payReward(
        NodeId node
    )
        external
        payable
        override
        onlyExistingActiveNode(node)
    {
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
            _rootFund.supply(
                balance,
                FundLibrary.nodeToHolder(node),
                amount
            );
        } else {
            assert(!_disabledNodesBalances.set(
                node,
                _disabledNodesBalances.get(node) + amount)
            );
            totalDisabled = totalDisabled + amount;
        }
        emit NodeRewardReceived(node, amount);

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_rootFund.credits.get(FundLibrary.nodeToHolder(node))));
        }
    }


    /**
     * @notice Claims an exit request and transfers funds to the caller
     * @dev Reverts if the request is still locked or doesn't belong to the caller
     * @param requestId The ID of the exit request to claim
     */
    function claimRequest(uint256 requestId) external override nonReentrant {
        Fair amount = _exitQueue.claim(msg.sender, requestId);
        payable(msg.sender).sendValue(Fair.unwrap(amount));
    }

    /**
     * @notice Sets the maximum stake allowed per node
     * @dev Only callable by authorized addresses (restricted)
     * @param limit The new stake limit
     */
    function setStakeLimit(Fair limit) external override restricted {
        emit StakeLimitUpdated(limit);
        stakeLimit = limit;
    }

    /**
     * @notice Sets the delay period for exit requests
     * @dev Only callable by authorized addresses (restricted)
     * @dev Even if delay is 0, the request cannot be created and claimed in the same block
     * @param delay The new retrieving delay
     */
    function setRetrievingDelay(Timestamp delay) external override restricted {
        _exitQueue.retrievingDelay = delay;
        emit RetrievingDelayUpdated(delay);
    }

    /**
     * @notice Sets the fee rate for the caller's node
     * @dev Only callable by node owners
     * @dev Fee rate can only be reduced, not increased (except if there are no stakers to the node)
     * @dev Pulls any pending rewards before updating the rate
     * @param feeRate The new fee rate (must be <= FEE_RATE_PRECISION)
     */
    function setFeeRate(uint16 feeRate) external override {
        // Constant + 1 optimized by the compiler - not computed at runtime
        require(feeRate < FundLibrary.FEE_RATE_PRECISION + 1, FeeRateIsIncorrect(feeRate));
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
     * @notice Requests to retrieve all stake from a specific node
     * @dev Creates an exit request for the caller's entire stake in the node
     * @param node The node from which to retrieve all stake
     */
    function requestRetrieveAll(NodeId node) external override {
        requestRetrieve(node, getStakedToNodeAmountFor(node, msg.sender));
    }

    /**
     * @notice Stakes to a specific node
     * @dev Only works on existing active nodes
     * @dev msg.value must be greater than 0
     * @param node The node to stake to
     */
    function stake(NodeId node) external payable override onlyExistingActiveNode(node) {
        _stakeFor(node, msg.sender);
    }

    /**
     * @notice Gets the node's share of the total credits
     * @dev Returns 0 if node is disabled
     * @dev Accounts for un-pulled rewards from the node's reward wallet
     * @param node The node to query
     * @return share The node's share in credits
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
     * @notice Gets the reward wallet contract for a specific node
     * @dev Reverts if reward wallet doesn't exist
     * @param node The node to query
     * @return rewardWallet The reward wallet contract
     */
    function getRewardWallet(NodeId node) external view override returns (IRewardWallet rewardWallet) {
        rewardWallet = _rewardWallets[node];
        require(rewardWallet != IRewardWallet(payable(0)), RewardWalletDoesNotExist(node));
    }

    /**
     * @notice Gets the total amount staked by the caller
     * @return amount The total staked amount
     */
    function getStakedAmount() external view override returns (Fair amount) {
        return getStakedAmountFor(msg.sender);
    }

    /**
     * @notice Gets the amount the caller has staked to a specific node
     * @param node The node to query
     * @return amount The staked amount
     */
    function getStakedToNodeAmount(NodeId node) external view override returns (Fair amount) {
        return getStakedToNodeAmountFor(node, msg.sender);
    }

    /**
     * @notice Gets the list of nodes the caller has stake in
     * @return stakedNodes Array of node IDs
     */
    function getStakedNodes() external view override returns (NodeId[] memory stakedNodes) {
        return getStakedNodesFor(msg.sender);
    }

    /**
     * @notice Gets the total stake for a specific node
     * @param node The node to query
     * @return amount The total stake on the node
     */
    function getNodeTotalStake(NodeId node) external view override returns (Fair amount) {
        return _getNodeTotalStakeBeforeAmount(node, FundLibrary.ZERO_FAIR);
    }

    /**
     * @notice Gets the current fee rate for a specific node
     * @param node The node to query
     * @return feeRate The node's current fee rate
     */
    function getNodeFeeRate(NodeId node) external view override returns (uint16 feeRate) {
        return _nodesFunds[node].feeRate;
    }

    /**
     * @notice Gets the list of all delegators (stakers) to a specific node
     * @param node The node to query
     * @return delegators Array of delegator addresses
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
     * @notice Gets the number of delegators to a specific node
     * @param node The node to query
     * @return count The number of delegators
     */
    function getDelegatorsToNodeCount(NodeId node) external view override returns (uint256 count) {
        count = _nodesFunds[node].credits.length();
    }

    /**
     * @notice Gets the number of exit requests for a specific user
     * @param user The user to query
     * @return count The number of exit requests
     */
    function getExitRequestsCountFor(address user) external view override returns (uint256 count) {
        return _exitQueue.getNumRequestsForUser(user);
    }

    /**
     * @notice Gets the caller's total amount in the exit queue
     * @return amount The total amount waiting in exit queue
     */
    function getMyTotalInExitQueue() external view override returns (Fair amount) {
        return _exitQueue.getTotalInQueueForUser(msg.sender);
    }

    /**
     * @notice Gets the number of exit requests for the caller
     * @return count The number of exit requests
     */
    function getMyExitRequestsCount() external view override returns (uint256 count) {
        return _exitQueue.getNumRequestsForUser(msg.sender);
    }

    /**
     * @notice Checks if a node's current stake is within the configured stake limit
     * @param node The node to check
     * @return result True if within stake limit, false otherwise
     */
    function isWithinStakeLimit(NodeId node) external view override returns (bool result) {
        (result,) = _isWithinStakeLimit(node, FundLibrary.ZERO_FAIR);
    }

    /**
     * @notice Gets information about a specific exit request
     * @param requestId The ID of the exit request
     * @return request The exit request details
     */
    function getExitRequest(
        uint256 requestId
    )
        external
        view
        override
        returns (ExitRequest memory request)
    {
        request = _exitQueue.getRequest(requestId);
    }

    /**
     * @notice Gets the first unlocked exit request found for a user starting from a specific index
     * @dev Does limited iterations to avoid DoS and gas limit issues
     * @param user The user to query
     * @param fromIndex The index to start searching from
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
     * @param user The user to query
     * @param index The index of the exit request
     * @return request The exit request at the specified index
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
     * @notice Checks if an exit request is unlocked and can be claimed
     * @param requestId The ID of the exit request
     * @return unlocked True if the request is unlocked, false otherwise
     */
    function isRequestUnlocked(uint256 requestId) external view override returns (bool unlocked) {
        return _exitQueue.isRequestUnlocked(requestId);
    }

    /**
     * @notice Gets the current retrieving delay
     * @return delay The time delay before exit requests can be claimed
     */
    function getRetrievingDelay() external view override returns (Timestamp delay) {
        return _exitQueue.retrievingDelay;
    }

    /**
     * @notice Gets the total amount in the exit queue for a specific user
     * @param user The user to query
     * @return amount The total amount in exit queue
     */
    function getTotalInExitQueueFor(address user) external view override returns (Fair amount){
        return _exitQueue.getTotalInQueueForUser(user);
    }

    // Public

    /**
     * @notice Requests to retrieve a specific amount of stake from a node
     * @dev Creates an exit request and updates committee weight if the node is enabled
     * @dev value must be greater than 0 and less than or equal to the caller's stake in the node
     * @param node The node from which to retrieve stake
     * @param value The amount to retrieve
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
     * @notice Requests a specific amount of fees for a node
     * @dev Only callable by allowed receivers or node owner
     * @dev Creates an exit request for the sender
     * @param node The node from which to request fees
     * @param amount The amount of fees to request
     */
    function requestFees(
        NodeId node,
        Fair amount
    )
        public
        override
        onlyExistingActiveNode(node)
    {
        require(amount > FundLibrary.ZERO_FAIR, ZeroAmount());
        bool senderIsOwner = msg.sender == nodes.getNode(node).nodeAddress;
        require(
            _nodesAllowedReceivers[node].contains(msg.sender) || senderIsOwner,
            NotAllowedToClaimRewards(msg.sender)
        );
        _requestSendFees(node, amount, payable(msg.sender));
        _exitQueue.createRequest(payable(msg.sender), node, amount);
    }

    /**
     * @notice Requests to send fees to a specific address
     * @dev Only callable by node owners
     * @dev If allowed receivers are configured, destination must be in the list or be the owner
     * @param to The address to receive the fees
     * @param amount The amount of fees to send
     */
    function requestSendFees(address payable to, Fair amount) public override {
        require(amount > FundLibrary.ZERO_FAIR, ZeroAmount());
        NodeId node = nodes.getNodeId(msg.sender);

        // Node has opted in to allowed receivers, so the destination address must be in the list
        // Or be the owner
        if (_hasAllowedReceiver(node)) {
            require(
                _nodesAllowedReceivers[node].contains(to) || to == msg.sender,
                NotAllowedToClaimRewards(to)
            );
        }
        _requestSendFees(node, amount, to);
        _exitQueue.createRequest(to, node, amount);
    }

    /**
     * @notice Checks if a node is currently enabled
     * @param node The node to check
     * @return enabled True if the node is enabled, false otherwise
     */
    function isNodeEnabled(NodeId node) public view override returns (bool enabled) {
        return !_disabledNodesBalances.contains(node);
    }

    /**
     * @notice Gets the amount of fees earned by a node
     * @dev Includes non-pulled rewards from the reward wallet
     * @param node The node to query
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
     * @notice Gets the total amount staked by a specific holder across all nodes
     * @param holder The address to query
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
     * @notice Gets the list of nodes a specific holder has staked to
     * @param holder The address to query
     * @return stakedNodes Array of node IDs
     */
    function getStakedNodesFor(address holder) public view override returns (NodeId[] memory stakedNodes) {
        return _stakedNodes[holder].values();
    }

    /**
     * @notice Gets the amount a specific holder has staked to a specific node
     * @dev Includes non-pulled rewards in the calculation
     * @param node The node to query
     * @param holder The address to query
     * @return amount The staked amount for this holder on this node
     */
    function getStakedToNodeAmountFor(NodeId node, address holder) public view override returns (Fair amount) {
        Fair nodeBalance;
        Fair nonPulledReward = _getNonPulledReward(node);
        if (!isNodeEnabled(node)) {
            nodeBalance = _disabledNodesBalances.get(node) + nonPulledReward;
        } else {
            nodeBalance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)) + nonPulledReward;
        }
        return _nodesFunds[node].getBalance(
            nodeBalance,
            FundLibrary.addressToHolder(holder)
        );
    }

    /**
     * @notice Gets the total amount currently in the exit queue across all users
     * @return amount The total amount waiting in exit queue
     */
    function getTotalInExitQueue() public view override returns (Fair amount) {
        return _exitQueue.totalInExitQueue;
    }

    // Private

    /**
     * @notice Stakes ETH to a node on behalf of a specific staker
     * @dev Validates stake limit and updates committee weight if node is enabled
     * @param node The node to stake to
     * @param staker The address of the staker
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
            _rootFund.supply(
                balance,
                FundLibrary.nodeToHolder(node),
                amount
            );
        } else {
            Fair nodeFundBalance = _disabledNodesBalances.get(node);
            _nodesFunds[node].supply(
                nodeFundBalance,
                FundLibrary.addressToHolder(staker),
                amount
            );
            assert(!_disabledNodesBalances.set(node, nodeFundBalance + amount));
            totalDisabled = totalDisabled + amount;
        }
        if(_stakedNodes[staker].add(node)) {
            emit StakedToNewNode(staker, node);
        }

        if (nodeIsEnabled) {
            // Reward Wallet already flushed
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

    /**
     * @notice Internal function to request and process fee claims to a specific address
     * @dev Processes fee claim and updates committee weight if node is enabled
     * @param node The node from which to claim fees
     * @param amount The amount of fees to claim
     * @param to The address to receive the fees
     */
    function _requestSendFees(
        NodeId node,
        Fair amount,
        address to
    )
        private
    {
        // sender can be allowed user, nodeOwner, or Nodes.sol contract (node deleted)
        emit FeeClaimRequested(node, msg.sender, to, amount);
        _pullReward(node);
        Fair balance = _getTotalBalance();
        bool nodeIsEnabled = isNodeEnabled(node);
        if (nodeIsEnabled) {
            _nodesFunds[node].claimFee(
                _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
                amount
            );
            _rootFund.remove(
                balance,
                FundLibrary.nodeToHolder(node),
                amount
            );
        } else {
            Fair nodeBalance = _disabledNodesBalances.get(node);
            _nodesFunds[node].claimFee(
                nodeBalance,
                amount
            );
            // node is already disabled, should return false
            assert(!_disabledNodesBalances.set(node, nodeBalance - amount));
            totalDisabled = totalDisabled - amount;
        }

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

    /**
     * @notice Retrieves funds for a specific staker from a node
     * @dev Validates node owner restrictions and updates balances
     * @param node The node from which to retrieve funds
     * @param value The amount to retrieve
     * @param staker The address of the staker
     * @return nodeIsEnabled True if the node is enabled, false otherwise
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
            _rootFund.remove(
                balance,
                FundLibrary.nodeToHolder(node),
                value
            );
        } else {
            Fair nodeFundBalance = _disabledNodesBalances.get(node);
            _nodesFunds[node].remove(
                nodeFundBalance,
                FundLibrary.addressToHolder(staker),
                value
            );
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
     * @notice Wrapper function to retrieve funds for the message sender
     * @dev Calls _retrieveFundsFor with msg.sender as the staker
     * @param node The node from which to retrieve funds
     * @param value The amount to retrieve
     * @return nodeIsEnabled True if the node is enabled, false otherwise
     */
    function _retrieveFunds(NodeId node, Fair value) private returns (bool nodeIsEnabled) {
        return _retrieveFundsFor(node, value, msg.sender);
    }

    /**
     * @notice Deploys a new reward wallet for a node
     * @dev Creates a new BeaconProxy pointing to rewardWalletBeacon Beacon contract
     * @param node The node for which to deploy the reward wallet
     */
    function _deployRewardWallet(NodeId node) private {
        emit RewardWalletCreated(node);
        _rewardWallets[node] = IRewardWallet(payable(new BeaconProxy(
            address(rewardWalletBeacon),
            abi.encodeWithSelector(
                IRewardWallet.initialize.selector,
                authority(),
                IStaking(payable(this)),
                nodes,
                node
            )
        )));
    }


    /**
     * @notice Pulls pending rewards from a node's reward wallet
     * @dev Protected against reentrancy, flushes the reward wallet if it has balance
     * @param node The node whose rewards to pull
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
     * @notice Updates the fee rate for a node's fund
     * @dev Calculates balance based on whether node is enabled or disabled
     * @param node The node whose fee rate to update
     * @param feeRate The new fee rate
     */
    function _updateNodeFeeRate(NodeId node, uint16 feeRate) private {
        Fair balance;
        if (isNodeEnabled(node)){
            balance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node));
        }
        else {
            balance = _disabledNodesBalances.get(node);
        }
        _nodesFunds[node].setFeeRate(
            balance,
            feeRate
        );
    }

    /**
     * @notice Checks that the provided self-stake meets the requirement
     * @dev Reverts if provided stake (msg.value) is less than the minimum self-stake requirement
     * @param nodeId The node being created
     */
    function _checkProvidedSelfStake(NodeId nodeId) private {
        Fair providedStake = Fair.wrap(msg.value);
        require(
            !(selfStakeRequirement > providedStake),
            InsufficientSelfStake(providedStake, selfStakeRequirement)
        );
        emit SelfStakeProvided(nodeId, providedStake);
    }

    /**
     * @notice Gets the credits for a specific node
     * @dev Validates that existence matches whether credits are zero
     * @param node The node to query
     * @return credits The node's credits
     */
    function _getNodeCredits(NodeId node) private view returns (Credit credits) {
        (bool exists, Credit amount) = _rootFund.credits.tryGet(FundLibrary.nodeToHolder(node));
        credits = amount;
        // If exists credits is not 0, otherwise it is 0.
        assert(exists != (credits == FundLibrary.ZERO_CREDIT));
    }

    /**
     * @notice Gets the total stake for a node before adding a specific amount
     * @dev Used to calculate stake limits before adding new stake
     * @param node The node to query
     * @param amount The amount that will be added (used for calculation)
     * @return total The total stake
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
     * @notice Gets the non-pulled reward balance for a node
     * @dev Returns zero if reward wallet doesn't exist
     * @param node The node to query
     * @return nonPulledReward The balance of the node's reward wallet
     */
    function _getNonPulledReward(NodeId node) private view returns (Fair nonPulledReward) {
        if (_rewardWallets[node] == IRewardWallet(payable(0))) {
            return FundLibrary.ZERO_FAIR;
        }
        return Fair.wrap(address(_rewardWallets[node]).balance);
    }

    /**
     * @notice Gets the total balance available in the root fund
     * @dev Excludes disabled nodes balance and exit queue from contract balance
     * @return balance The total available balance
     */
    function _getTotalBalance() private view returns (Fair balance) {
        return Fair.wrap(address(this).balance) - totalDisabled - getTotalInExitQueue();
    }

    /**
     * @notice Checks if staking an amount to a node would be within the stake limit
     * @dev Returns true if no stake limit is configured
     * @param node The node to check
     * @param amount The amount to be staked
     * @return result True if within limit, false otherwise
     * @return currentNodeStake The current stake on the node
     */
    function _isWithinStakeLimit(
        NodeId node,
        Fair amount
    )
        private
        view
        returns (bool result, Fair currentNodeStake)
    {
        result = true;
        if (stakeLimit > FundLibrary.ZERO_FAIR) {
            currentNodeStake = _getNodeTotalStakeBeforeAmount(node, amount);
            Fair newNodeStake = currentNodeStake + amount;
            result = !(newNodeStake > stakeLimit);
        }
    }

    /**
     * @notice Validates that staking an amount doesn't exceed the stake limit
     * @dev Reverts with StakeLimitExceeded if limit would be exceeded
     * @param node The node to check
     * @param amount The amount to be staked
     */
    function _validateStakeLimit(NodeId node, Fair amount) private view {
        (bool isWithinLimit, Fair currentNodeStake) = _isWithinStakeLimit(node, amount);
        require(
            isWithinLimit,
            StakeLimitExceeded(currentNodeStake, amount, stakeLimit)
        );
    }

    /**
     * @notice Checks if a node has any allowed receivers configured
     * @dev Returns true if the allowed receivers set is non-empty
     * @param node The node to check
     * @return result True if the node has allowed receivers, false otherwise
     */
    function _hasAllowedReceiver(NodeId node) private view returns (bool result) {
        return _nodesAllowedReceivers[node].length() > 0;
    }

    /**
     * @notice Ensures a node owner cannot retrieve stake while their node exists
     * @dev Reverts if the node is active and sender is the node owner
     * @param sender The address attempting to retrieve
     * @param node The node from which retrieval is attempted
     */
    function _checkNodeOwnerRestriction(address sender, NodeId node) private view {
        if (nodes.activeNodeExists(node)) {
            address nodeOwner = nodes.getNode(node).nodeAddress;
            require(
                sender != nodeOwner,
                NodeOwnerCannotRetrieveWhileNodeExists(sender, node)
            );
        }
    }

    /**
     * @notice Converts a public key to a solidity address
     * @dev Uses keccak256 hash of the concatenated public key components
     * @param pubKey The public key as a 2-element bytes32 array
     * @return nodeAddress The derived solidity address
     */
    function _publicKeyToAddress(
        bytes32[2] memory pubKey
    )
        private
        pure
        returns (address nodeAddress)
    {
        bytes32 hash = keccak256(abi.encodePacked(pubKey[0], pubKey[1]));
        return address(uint160(uint256(hash)));
    }

}
