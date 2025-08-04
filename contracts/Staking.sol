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
import {ICommittee} from "@skalenetwork/fair-manager-interfaces/ICommittee.sol";
import {INodes, NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {IRewardWallet} from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import {IStaking} from "@skalenetwork/fair-manager-interfaces/IStaking.sol";

import {Nodes} from "./Nodes.sol";
import {TypedMap} from "./structs/typed/TypedMap.sol";
import {TypedSet} from "./structs/typed/TypedSet.sol";
import {Credit, FundLibrary, Fair} from "./utils/Fund.sol";


contract Staking is AccessManagedUpgradeable, ReentrancyGuardUpgradeable, IStaking {
    using Address for address payable;
    using FundLibrary for FundLibrary.Fund;
    using TypedSet for TypedSet.NodeIdSet;
    using TypedMap for TypedMap.NodeIdToFairMap;

    ICommittee public committee;
    INodes public nodes;
    IRewardWallet public rewardWalletReference;
    Fair public totalDisabled;
    FundLibrary.Fund private _rootFund;
    mapping (NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;
    mapping (NodeId node => IRewardWallet rewardWallet) private _rewardWallets;
    mapping (address holder => TypedSet.NodeIdSet nodeIds) private _stakedNodes;
    TypedMap.NodeIdToFairMap private _disabledNodesBalances;
    Fair public stakeLimit;

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

    error FeeRateIsIncorrect(uint16 feeRate);
    error OnlyFeeReductionIsAllowed(uint16 currentRate, uint16 newRate);
    error ZeroAmount();
    error ZeroStakeToNode(NodeId node);
    error NodeIsAlreadyDisabled(NodeId node);
    error NodeIsNotDisabled(NodeId node);
    error StakeLimitExceeded(Fair currentStake, Fair attemptedStake, Fair limit);
    error ZeroAddress();
    error RewardWalletDoesNotExist(NodeId node);

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

    function claimAllFee(address payable to) external override {
        claimFee(to, getEarnedFeeAmount(nodes.getNodeId(msg.sender)));
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

    function enable(NodeId node) external override restricted {
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
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
        uint16 defaultFeeRate = 1000;
        _updateNodeFeeRate(node, defaultFeeRate);
    }

    function payReward(NodeId node) external payable override {
        require(msg.value > 0, ZeroAmount());
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
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
        }
        emit NodeRewardReceived(node, amount);

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
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

        if (_nodesFunds[node].credits[FundLibrary.addressToHolder(msg.sender)] == FundLibrary.ZERO_CREDIT) {
            assert(_stakedNodes[msg.sender].remove(node));
            emit StoppedStaking(msg.sender, node);
        }

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
        }
        payable(msg.sender).sendValue(Fair.unwrap(value));
    }

    function setFeeRate(uint16 feeRate) external override {
        require(!(1000 < feeRate), FeeRateIsIncorrect(feeRate));
        NodeId node = nodes.getNodeId(msg.sender);
        uint16 currentFeeRate = _nodesFunds[node].feeRate;
        require(
            _nodesFunds[node].totalCredits == FundLibrary.ZERO_CREDIT || feeRate < currentFeeRate,
            OnlyFeeReductionIsAllowed(currentFeeRate, feeRate)
        );

        _updateNodeFeeRate(node, feeRate);
    }

    function setRewardWalletReference(IRewardWallet rewardWalletReference_) external override restricted {
        rewardWalletReference = rewardWalletReference_;
    }

    function stake(NodeId node) external payable override {
        require(msg.value > 0, ZeroAmount());
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
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
            committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
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
                unPulledCredits = rewardWalletBalance *
                    Credit.unwrap(_rootFund.totalCredits) / Fair.unwrap(totalBalance);
            } else {
                unPulledCredits = rewardWalletBalance;
            }
        }
        return Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]) + unPulledCredits;
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

    // Public

    function claimFee(address payable to, Fair amount) public override {
        require(to != address(0), ZeroAddress());
        NodeId node = nodes.getNodeId(msg.sender);
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
            _nodesFunds[node].claimFee(
                _disabledNodesBalances.get(node),
                amount
            );
        }

        if (nodeIsEnabled) {
            committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
        }
        to.sendValue(Fair.unwrap(amount));
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
        if (address(_rewardWallets[node]).balance > 0) {
            // Reward wallet is considered as a part of Staking contract.
            // The code is trusted and effects are known.
            // slither-disable-start reentrancy-events
            // slither-disable-next-line reentrancy-benign
            _rewardWallets[node].flush();
            // slither-disable-end reentrancy-events
        }
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

    function _updateNodeFeeRate(NodeId node, uint16 feeRate) private {
        _nodesFunds[node].setFeeRate(
            _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)),
            feeRate
        );
    }

}
