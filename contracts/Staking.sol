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
import {Credit, FundLibrary, Fair, Holder} from "./utils/Fund.sol";


contract Staking is AccessManagedUpgradeable, ReentrancyGuardUpgradeable, IStaking {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using FundLibrary for FundLibrary.Fund;
    using TypedSet for TypedSet.NodeIdSet;
    using TypedMap for TypedMap.HolderToCreditMap;
    using TypedMap for TypedMap.NodeIdToFairMap;

    ICommittee public committee;
    INodes public nodes;
    IRewardWallet public rewardWalletReference;
    Fair public totalDisabled;
    FundLibrary.Fund private _rootFund;
    mapping (NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;
    mapping (NodeId node => IRewardWallet rewardWallet) private _rewardWallets;
    mapping (NodeId node => EnumerableSet.AddressSet allowedReceivers) private _nodesAllowedReceivers;
    mapping (address holder => TypedSet.NodeIdSet nodeIds) private _stakedNodes;
    TypedMap.NodeIdToFairMap private _disabledNodesBalances;
    Fair public stakeLimit;
    uint16 public constant DEFAULT_FEE_RATE = 1000;

    event AllowedReceiverAdded(NodeId indexed node, address indexed receiver);
    event AllowedReceiverRemoved(NodeId indexed node, address indexed receiver);
    event FeeClaimed(NodeId indexed node, address indexed to, Fair indexed amount);
    event NodeRewardReceived(NodeId indexed node, Fair indexed amount);
    event Retrieved(address indexed sender, NodeId indexed node, Fair indexed amount);
    event RewardReceived(address indexed sender, uint256 indexed amount);
    event RewardWalletCreated(NodeId indexed node);
    event Staked(address indexed sender, NodeId indexed node, Fair indexed amount);
    event StakedToNewNode(address indexed sender, NodeId indexed node);
    event StoppedStaking(address indexed sender, NodeId indexed node);
    event NodeDisabled(NodeId indexed node);
    event NodeEnabled(NodeId indexed node);
    event StakeLimitUpdated(Fair indexed newLimit);
    event NodeFeeRateUpdated(NodeId indexed node, uint16 oldFeeRate, uint16 newFeeRate);
    event RewardWalletReferenceUpdated(IRewardWallet indexed oldReference, IRewardWallet indexed newReference);

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

    function claimAllFees(NodeId node) external override {
        // Works for deleted Nodes
        claimFees(node, getEarnedFeeAmount(node));
    }

    function sendAllFees(address payable to) external override {
        // Does not work for deleted Nodes
        sendFees(to, getEarnedFeeAmount(nodes.getNodeId(msg.sender)));
    }

    function disable(NodeId node) external override restricted {
        _pullReward(node);
        Fair balance = _getTotalBalance();
        Fair nodeFundBalance = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
        _rootFund.remove(
            balance,
            FundLibrary.nodeToHolder(node),
            nodeFundBalance
        );
        require(_disabledNodesBalances.set(node, nodeFundBalance), NodeIsAlreadyDisabled(node));
        totalDisabled = totalDisabled + nodeFundBalance;
        emit NodeDisabled(node);
        committee.updateWeight(node, 0);
    }

    function enable(
        NodeId node
    )
        external
        override
        restricted
        onlyExistingActiveNode(node)
    {
        (bool wasDisabled, Fair value) = _disabledNodesBalances.tryGet(node);
        require(wasDisabled, NodeIsNotDisabled(node));
        _pullReward(node);
        Fair balance = _getTotalBalance();
        _rootFund.supply(
            balance,
            FundLibrary.nodeToHolder(node),
            value
        );
        assert(_disabledNodesBalances.remove(node));
        totalDisabled = totalDisabled - value;
        emit NodeEnabled(node);
    }

    function nodeCreated(NodeId node) external override restricted {
        if(_rewardWallets[node] == IRewardWallet(payable(0))) {
            _deployRewardWallet(node);
        }
        _updateNodeFeeRate(node, DEFAULT_FEE_RATE);
        assert(_disabledNodesBalances.set(node, FundLibrary.ZERO_FAIR));
    }

    function payReward(
        NodeId node
    )
        external
        payable
        override
    {
        require(msg.value > 0, ZeroAmount());

        if (!nodes.activeNodeExists(node)) {
            // Node was deleted or never registered -> reward is shared with all stakers
            emit RewardReceived(msg.sender, msg.value);
            return;
        }

        bool nodeIsEnabled = !_disabledNodesBalances.contains(node);
        Fair amount = Fair.wrap(msg.value);
        Fair balance = _getTotalBalance() - amount;
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

    function setStakeLimit(Fair limit) external override restricted {
        emit StakeLimitUpdated(limit);
        stakeLimit = limit;
    }

    function retrieve(NodeId node, Fair value) external override {
        require(value > FundLibrary.ZERO_FAIR, ZeroAmount());
        require(_stakedNodes[msg.sender].contains(node), ZeroStakeToNode(node));

        emit Retrieved(msg.sender, node, value);

        _pullReward(node);
        bool nodeIsEnabled = isNodeEnabled(node);
        if (nodeIsEnabled) {
            Fair balance = _getTotalBalance();
            _nodesFunds[node].remove(
                _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
                FundLibrary.addressToHolder(msg.sender),
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
                FundLibrary.addressToHolder(msg.sender),
                value
            );
            assert(!_disabledNodesBalances.set(node, nodeFundBalance - value));
            totalDisabled = totalDisabled - value;
        }
        (bool exists, Credit holderCredits) = _nodesFunds[node].credits.tryGet(FundLibrary.addressToHolder(msg.sender));
        if (holderCredits == FundLibrary.ZERO_CREDIT) {
            assert(_stakedNodes[msg.sender].remove(node) && !exists);
            emit StoppedStaking(msg.sender, node);
        }

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
        payable(msg.sender).sendValue(Fair.unwrap(value));
    }

    function setFeeRate(uint16 feeRate) external override {
        require(!(feeRate > 1000), FeeRateIsIncorrect(feeRate));
        NodeId node = nodes.getNodeId(msg.sender);
        uint16 currentFeeRate = _nodesFunds[node].feeRate;
        require(
            _nodesFunds[node].totalCredits == FundLibrary.ZERO_CREDIT || feeRate < currentFeeRate,
            OnlyFeeReductionIsAllowed(currentFeeRate, feeRate)
        );

        emit NodeFeeRateUpdated(node, currentFeeRate, feeRate);
        _updateNodeFeeRate(node, feeRate);
    }

    function setRewardWalletReference(IRewardWallet rewardWalletReference_) external override restricted {
        emit RewardWalletReferenceUpdated(rewardWalletReference, rewardWalletReference_);
        rewardWalletReference = rewardWalletReference_;
    }

    function stake(NodeId node) external payable override onlyExistingActiveNode(node) {
        require(msg.value > 0, ZeroAmount());
        bool nodeIsEnabled = isNodeEnabled(node);
        Fair amount = Fair.wrap(msg.value);
        emit Staked(msg.sender, node, amount);
        _pullReward(node);
        Fair balance = _getTotalBalance() - amount;

        _validateStakeLimit(node, amount, balance, nodeIsEnabled);

        if (nodeIsEnabled) {
            _nodesFunds[node].supply(
                _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
                FundLibrary.addressToHolder(msg.sender),
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
                FundLibrary.addressToHolder(msg.sender),
                amount
            );
            assert(!_disabledNodesBalances.set(node, nodeFundBalance + amount));
            totalDisabled = totalDisabled + amount;
        }
        if(_stakedNodes[msg.sender].add(node)) {
            emit StakedToNewNode(msg.sender, node);
        }

        if (nodeIsEnabled) {
            // Reward Wallet already flushed
            committee.updateWeight(node, Credit.unwrap(_getNodeCredits(node)));
        }
    }

    function getNodeShare(NodeId node) external view override returns (uint256 share) {
        if (!isNodeEnabled(node)) {
            return 0;
        }
        Fair totalBalance = _getTotalBalance();
        assert((totalBalance == FundLibrary.ZERO_FAIR) == (_rootFund.totalCredits == FundLibrary.ZERO_CREDIT));
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
        if (isNodeEnabled(node)) {
            Fair balance = _getTotalBalance();
            amount = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
        } else {
            amount = _disabledNodesBalances.get(node);
        }
        amount = amount + _getNonPulledReward(node);
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

    // Public

    function claimFees(NodeId node, Fair amount) public override {
        // works for deleted Nodes
        bool senderIsOwner = msg.sender == _publicKeyToAddress(nodes.getPublicKey(node));
        require(
            _nodesAllowedReceivers[node].contains(msg.sender) || senderIsOwner,
            NotAllowedToClaimRewards(msg.sender)
        );
        _sendFees(
            node,
            amount,
            payable(msg.sender)
        );
    }

    function sendFees(address payable to, Fair amount) public override {
        NodeId node = nodes.getNodeId(msg.sender);

        // Node has opted in to allowed receivers, so the destination address must be in the list
        // Or be the owner
        if (_hasAllowedReceiver(node)) {
            require(
                _nodesAllowedReceivers[node].contains(to) || to == msg.sender,
                NotAllowedToClaimRewards(to)
            );
        }
        _sendFees(
            node,
            amount,
            to
        );
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

    // Private

    function _sendFees(
        NodeId node,
        Fair amount,
        address payable to
    )
        private
    {
        emit FeeClaimed(node, to, amount);
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
        to.sendValue(Fair.unwrap(amount));
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
                node
            )
        )));
    }


    function _pullReward(NodeId node) private nonReentrant {

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
        _nodesFunds[node].setFeeRate(
            _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)),
            feeRate
        );
    }

    function _getNodeCredits(NodeId node) private view returns (Credit credits) {
        (bool exists, Credit amount) = _rootFund.credits.tryGet(FundLibrary.nodeToHolder(node));
        credits = amount;
        // If exists credits is not 0, otherwise it is 0.
        assert(exists != (credits == FundLibrary.ZERO_CREDIT));
    }

    function _getNonPulledReward(NodeId node) private view returns (Fair nonPulledReward) {
        return Fair.wrap(address(_rewardWallets[node]).balance);
    }

    function _getTotalBalance() private view returns (Fair balance) {
        return Fair.wrap(address(this).balance) - totalDisabled;
    }

    function _validateStakeLimit(NodeId node, Fair amount, Fair balance, bool nodeIsEnabled) private view {
        if (Fair.unwrap(stakeLimit) > 0) {
            Fair currentNodeStake;
            if (nodeIsEnabled) {
                currentNodeStake = _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node));
            } else {
                currentNodeStake = _disabledNodesBalances.get(node);
            }

            Fair newNodeStake = currentNodeStake + amount;
            require(
                !(newNodeStake > stakeLimit),
                StakeLimitExceeded(currentNodeStake, amount, stakeLimit)
            );
        }
    }

    function _hasAllowedReceiver(NodeId node) private view returns (bool result) {
        return _nodesAllowedReceivers[node].length() > 0;
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
