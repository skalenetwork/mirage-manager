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

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    Address
} from "@openzeppelin/contracts/utils/Address.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICommittee} from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import {INodes, NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {IRewardWallet} from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import {IStaking} from "@skalenetwork/fair-manager-interfaces/IStaking.sol";

import {Nodes} from "./Nodes.sol";
import {TypedMap} from "./structs/typed/TypedMap.sol";
import {TypedSet} from "./structs/typed/TypedSet.sol";
import { DEFAULT_MIN_STAKE, DEFAULT_RETRIEVING_DELAY } from "./utils/constants.sol";
import {ExitQueueLibrary, Timestamp} from "./utils/ExitQueue.sol";
import {Credit, FundLibrary, Fair, Holder} from "./utils/Fund.sol";

contract Staking is AccessManagedUpgradeable, ReentrancyGuardUpgradeable, IStaking {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using FundLibrary for FundLibrary.Fund;
    using TypedSet for TypedSet.NodeIdSet;
    using TypedMap for TypedMap.HolderToCreditMap;
    using TypedMap for TypedMap.NodeIdToFairMap;
    using ExitQueueLibrary for ExitQueueLibrary.ExitQueue;

    // Starts equal to precision (max possible fee rate)
    uint16 public constant DEFAULT_FEE_RATE = FundLibrary.FEE_RATE_PRECISION;

    ICommittee public committee;
    INodes public nodes;
    IRewardWallet public rewardWalletReference;
    Fair public totalDisabled;
    Fair public stakeLimit;
    Fair public selfStakeRequirement;

    FundLibrary.Fund private _rootFund;
    ExitQueueLibrary.ExitQueue private _exitQueue;
    mapping (NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;
    mapping (NodeId node => IRewardWallet rewardWallet) private _rewardWallets;
    mapping (NodeId node => EnumerableSet.AddressSet allowedReceivers) private _nodesAllowedReceivers;
    mapping (address holder => TypedSet.NodeIdSet nodeIds) private _stakedNodes;
    TypedMap.NodeIdToFairMap private _disabledNodesBalances;

    event AllowedReceiverAdded(NodeId indexed node, address indexed receiver);
    event AllowedReceiverRemoved(NodeId indexed node, address indexed receiver);
    event FeeClaimRequested(NodeId indexed node, address from, address indexed to, Fair indexed amount);
    event NodeRewardReceived(NodeId indexed node, Fair indexed amount);
    event RetrieveRequested(address indexed sender, NodeId indexed node, Fair indexed amount);
    event RewardReceived(address indexed sender, uint256 indexed amount);
    event RewardWalletCreated(NodeId indexed node);
    event Staked(address indexed sender, NodeId indexed node, Fair indexed amount);
    event StakedToNewNode(address indexed sender, NodeId indexed node);
    event StoppedStaking(address indexed sender, NodeId indexed node);
    event NodeDataRemoved(NodeId indexed node);
    event NodeDisabled(NodeId indexed node);
    event NodeEnabled(NodeId indexed node);
    event RetrievingDelayUpdated(Timestamp indexed retrievingDelay);
    event StakeLimitUpdated(Fair indexed newLimit);
    event NodeFeeRateUpdated(NodeId indexed node, uint16 oldFeeRate, uint16 newFeeRate);
    event RewardWalletReferenceUpdated(IRewardWallet indexed oldReference, IRewardWallet indexed newReference);
    event SelfStakeRequirementUpdated(Fair indexed amount);
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

    function initialize(
        address initialAuthority,
        ICommittee committee_,
        INodes nodes_,
        IRewardWallet rewardWalletReference_
    )
        public
        initializer
        override
    {
        __AccessManaged_init(initialAuthority);
        __ReentrancyGuard_init();
        committee = committee_;
        nodes = nodes_;
        rewardWalletReference = rewardWalletReference_;
        // Default on initialize
        _exitQueue.retrievingDelay = Timestamp.wrap(DEFAULT_RETRIEVING_DELAY);
        selfStakeRequirement = Fair.wrap(DEFAULT_MIN_STAKE);
        emit RetrievingDelayUpdated(Timestamp.wrap(DEFAULT_RETRIEVING_DELAY));
    }

    receive() external override payable {
        emit RewardReceived(msg.sender, msg.value);
    }

    function addAllowedReceiver(address receiver) external override {
        NodeId node = nodes.getNodeId(msg.sender);
        bool added = _nodesAllowedReceivers[node].add(receiver);
        require(added, ReceiverIsAlreadyAllowed(receiver));
        emit AllowedReceiverAdded(node, receiver);
    }

    function removeAllowedReceiver(address receiver) external override {
        NodeId node = nodes.getNodeId(msg.sender);
        bool removed = _nodesAllowedReceivers[node].remove(receiver);
        require(removed, ReceiverWasNotAllowed(receiver));
        emit AllowedReceiverRemoved(node, receiver);
    }

    function requestAllFees(NodeId node) external override {
        requestFees(node, getEarnedFeeAmount(node));
    }

    function requestSendAllFees(address payable to) external override {
        requestSendFees(to, getEarnedFeeAmount(nodes.getNodeId(msg.sender)));
    }

    function setSelfStakeRequirement(Fair amount) external override restricted {
        selfStakeRequirement = amount;
        emit SelfStakeRequirementUpdated(amount);
    }

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

        // Node might have changed it's balance due to rounding in supply()
        // Force update on nodeFund
        Fair finalBalance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node));
        if(!(finalBalance == value)){
            _nodesFunds[node].updateTotalBalance(
                _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node))
            );
        }

        emit NodeEnabled(node);
    }

    function nodeCreated(NodeId node, address nodeAddress) external payable override restricted {
        if(_rewardWallets[node] == IRewardWallet(payable(0))) {
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


    function claimRequest(uint256 requestId) external override nonReentrant {
        Fair amount = _exitQueue.claim(msg.sender, requestId);
        payable(msg.sender).sendValue(Fair.unwrap(amount));
    }

    function setStakeLimit(Fair limit) external override restricted {
        emit StakeLimitUpdated(limit);
        stakeLimit = limit;
    }

    function setRetrievingDelay(Timestamp delay) external override restricted {
        _exitQueue.retrievingDelay = delay;
        emit RetrievingDelayUpdated(delay);
    }

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

    function setRewardWalletReference(IRewardWallet rewardWalletReference_) external override restricted {
        emit RewardWalletReferenceUpdated(rewardWalletReference, rewardWalletReference_);
        rewardWalletReference = rewardWalletReference_;
    }

    function requestRetrieveAll(NodeId node) external override {
        requestRetrieve(node, getStakedToNodeAmountFor(node, msg.sender));
    }

    function stake(NodeId node) external payable override onlyExistingActiveNode(node) {
        _stakeFor(node, msg.sender);
    }

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

    function getRewardWallet(NodeId node) external view override returns (IRewardWallet rewardWallet) {
        rewardWallet = _rewardWallets[node];
        require(rewardWallet != IRewardWallet(payable(0)), RewardWalletDoesNotExist(node));
    }

    function getStakedAmount() external view override returns (Fair amount) {
        return getStakedAmountFor(msg.sender);
    }

    function getStakedToNodeAmount(NodeId node) external view override returns (Fair amount) {
        return getStakedToNodeAmountFor(node, msg.sender);
    }

    function getStakedNodes() external view override returns (NodeId[] memory stakedNodes) {
        return getStakedNodesFor(msg.sender);
    }

    function getNodeTotalStake(NodeId node) external view override returns (Fair amount) {
        return _getNodeTotalStakeBeforeAmount(node, FundLibrary.ZERO_FAIR);
    }

    function getNodeFeeRate(NodeId node) external view override returns (uint16 feeRate) {
        return _nodesFunds[node].feeRate;
    }

    function getDelegatorsToNode(NodeId node) external view override returns (address[] memory delegators) {
        Holder[] memory holders = _nodesFunds[node].credits.keys();
        delegators = new address[](holders.length);
        uint256 loops = holders.length;
        for (uint256 i = 0; i < loops; ++i) {
            delegators[i] = FundLibrary.holderToAddress(holders[i]);
        }
    }

    function getDelegatorsToNodeCount(NodeId node) external view override returns (uint256 count) {
        count = _nodesFunds[node].credits.length();
    }

    function getExitRequestsCountFor(address user) external view override returns (uint256 count) {
        return _exitQueue.getNumRequestsForUser(user);
    }

    function getMyTotalInExitQueue() external view override returns (Fair amount) {
        return _exitQueue.getTotalInQueueForUser(msg.sender);
    }

    function getMyExitRequestsCount() external view override returns (uint256 count) {
        return _exitQueue.getNumRequestsForUser(msg.sender);
    }

    function isWithinStakeLimit(NodeId node) external view override returns (bool result) {
        (result,) = _isWithinStakeLimit(node, FundLibrary.ZERO_FAIR);
    }

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

    function isRequestUnlocked(uint256 requestId) external view override returns (bool unlocked) {
        return _exitQueue.isRequestUnlocked(requestId);
    }
    function getRetrievingDelay() external view override returns (Timestamp delay) {
        return _exitQueue.retrievingDelay;
    }

    function getTotalInExitQueueFor(address user) external view override returns (Fair amount){
        return _exitQueue.getTotalInQueueForUser(user);
    }

    // Public

    function requestRetrieve(NodeId node, Fair value) public override {
        // Private helper does all internal state changes and verifications
        (bool nodeIsEnabled) = _retrieveFunds(node, value);
        _exitQueue.createRequest(msg.sender, node, value);

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

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

    function isNodeEnabled(NodeId node) public view override returns (bool enabled) {
        return !_disabledNodesBalances.contains(node);
    }

    function getEarnedFeeAmount(NodeId node) public view override returns (Fair amount) {
        Fair nonPulledReward = _getNonPulledReward(node);
        if (!isNodeEnabled(node)) {
            return _nodesFunds[node].getEarnedFee(_disabledNodesBalances.get(node) + nonPulledReward);
        }
        return _nodesFunds[node].getEarnedFee(
            _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)) + nonPulledReward
        );
    }

    function getStakedAmountFor(address holder) public view override returns (Fair amount) {
        uint256 nodesCount = _stakedNodes[holder].length();
        for (uint256 nodeIndex; nodeIndex < nodesCount; ++nodeIndex) {
            NodeId node = _stakedNodes[holder].at(nodeIndex);
            amount = amount + getStakedToNodeAmountFor(node, holder);
        }
    }

    function getStakedNodesFor(address holder) public view override returns (NodeId[] memory stakedNodes) {
        return _stakedNodes[holder].values();
    }

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

    function getTotalInExitQueue() public view override returns (Fair amount) {
        return _exitQueue.totalInExitQueue;
    }

    // Private

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

    function _retrieveFunds(NodeId node, Fair value) private returns (bool nodeIsEnabled) {
        return _retrieveFundsFor(node, value, msg.sender);
    }

    function _deployRewardWallet(NodeId node) private {
        ProxyAdmin proxyAdmin = ProxyAdmin(ERC1967Utils.getAdmin());
        emit RewardWalletCreated(node);
        _rewardWallets[node] = IRewardWallet(payable(new TransparentUpgradeableProxy(
            address(rewardWalletReference),
            proxyAdmin.owner(),
            abi.encodeWithSelector(
                IRewardWallet.initialize.selector,
                authority(),
                IStaking(payable(this)),
                nodes,
                node
            )
        )));
    }


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

    function _checkProvidedSelfStake(NodeId nodeId) private {
        Fair providedStake = Fair.wrap(msg.value);
        require(
            !(selfStakeRequirement > providedStake),
            InsufficientSelfStake(providedStake, selfStakeRequirement)
        );
        emit SelfStakeProvided(nodeId, providedStake);
    }

    function _getNodeCredits(NodeId node) private view returns (Credit credits) {
        (bool exists, Credit amount) = _rootFund.credits.tryGet(FundLibrary.nodeToHolder(node));
        credits = amount;
        // If exists credits is not 0, otherwise it is 0.
        assert(exists != (credits == FundLibrary.ZERO_CREDIT));
    }

    function _getNodeTotalStakeBeforeAmount(NodeId node, Fair amount) private view returns (Fair total) {
        if (isNodeEnabled(node)) {
            Fair balance = _getTotalBalance() - amount;
            total = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
        } else {
            total = _disabledNodesBalances.get(node);
        }
        total = total + _getNonPulledReward(node);
    }

    function _getNonPulledReward(NodeId node) private view returns (Fair nonPulledReward) {
        if (_rewardWallets[node] == IRewardWallet(payable(0))) {
            return FundLibrary.ZERO_FAIR;
        }
        return Fair.wrap(address(_rewardWallets[node]).balance);
    }

    function _getTotalBalance() private view returns (Fair balance) {
        return Fair.wrap(address(this).balance) - totalDisabled - getTotalInExitQueue();
    }

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

    function _validateStakeLimit(NodeId node, Fair amount) private view {
        (bool isWithinLimit, Fair currentNodeStake) = _isWithinStakeLimit(node, amount);
        require(
            isWithinLimit,
            StakeLimitExceeded(currentNodeStake, amount, stakeLimit)
        );
    }

    function _hasAllowedReceiver(NodeId node) private view returns (bool result) {
        return _nodesAllowedReceivers[node].length() > 0;
    }

    function _checkNodeOwnerRestriction(address sender, NodeId node) private view {
        if (nodes.activeNodeExists(node)) {
            address nodeOwner = nodes.getNode(node).nodeAddress;
            require(
                sender != nodeOwner,
                NodeOwnerCannotRetrieveWhileNodeExists(sender, node)
            );
        }
    }

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
