// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Staking.sol - mirage-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   mirage-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   mirage-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {
    Address
} from "@openzeppelin/contracts/utils/Address.sol";
import {ICommittee} from "@skalenetwork/professional-interfaces/ICommittee.sol";
import {INodes, NodeId} from "@skalenetwork/professional-interfaces/INodes.sol";
import {IStaking} from "@skalenetwork/professional-interfaces/IStaking.sol";

import {Nodes} from "./Nodes.sol";
import {TypedSet} from "./structs/typed/TypedSet.sol";
import {Credit, FundLibrary, Playa} from "./utils/Fund.sol";


contract Staking is AccessManagedUpgradeable, IStaking {
    using Address for address payable;
    using FundLibrary for FundLibrary.Fund;
    using TypedSet for TypedSet.NodeIdSet;

    ICommittee public committee;
    INodes public nodes;
    FundLibrary.Fund private _rootFund;
    mapping (NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;
    mapping (address holder => TypedSet.NodeIdSet nodeIds) private _stakedNodes;

    event FeeClaimed(NodeId indexed node, address indexed to, Playa indexed amount);
    event Retrieved(address indexed sender, NodeId indexed node, Playa indexed amount);
    event RewardReceived(address indexed sender, uint256 indexed amount);
    event Staked(address indexed sender, NodeId indexed node, Playa indexed amount);
    event StakedToNewNode(address indexed sender, NodeId indexed node);
    event StoppedStaking(address indexed sender, NodeId indexed node);

    error FeeRateIsIncorrect(uint16 feeRate);
    error OnlyFeeReductionIsAllowed(uint16 currentRate, uint16 newRate);
    error ZeroAmount();
    error ZeroStakeToNode(NodeId node);

    function initialize(address initialAuthority, ICommittee committee_, INodes nodes_) public initializer override {
        __AccessManaged_init(initialAuthority);
        committee = committee_;
        nodes = nodes_;
    }

    receive() external override payable {
        emit RewardReceived(msg.sender, msg.value);
    }

    function claimAllFee(address payable to) external override {
        claimFee(to, getEarnedFeeAmount(nodes.getNodeId(msg.sender)));
    }

    function retrieve(NodeId node, Playa value) external override {
        require(value > FundLibrary.ZERO_PLAYA, ZeroAmount());
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
        require(_stakedNodes[msg.sender].contains(node), ZeroStakeToNode(node));

        Playa balance = _getTotalBalance();
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

        if (_nodesFunds[node].credits[FundLibrary.addressToHolder(msg.sender)] == FundLibrary.ZERO_CREDIT) {
            assert(_stakedNodes[msg.sender].remove(node));
            emit StoppedStaking(msg.sender, node);
        }
        emit Retrieved(msg.sender, node, value);

        committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
        payable(msg.sender).sendValue(Playa.unwrap(value));
    }

    function setFeeRate(uint16 feeRate) external override {
        require(!(1000 < feeRate), FeeRateIsIncorrect(feeRate));
        NodeId node = nodes.getNodeId(msg.sender);
        uint16 currentFeeRate = _nodesFunds[node].feeRate;
        require(
            _nodesFunds[node].totalCredits == FundLibrary.ZERO_CREDIT || feeRate < currentFeeRate,
            OnlyFeeReductionIsAllowed(currentFeeRate, feeRate)
        );

        _nodesFunds[node].setFeeRate(
            _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node)),
            feeRate
        );
    }

    function stake(NodeId node) external payable override {
        require(msg.value > 0, ZeroAmount());
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
        Playa amount = Playa.wrap(msg.value);
        Playa balance = _getTotalBalance() - amount;
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
        if(_stakedNodes[msg.sender].add(node)) {
            emit StakedToNewNode(msg.sender, node);
        }
        emit Staked(msg.sender, node, amount);

        committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
    }

    function getNodeShare(NodeId node) external view override returns (uint256 share) {
        return Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]);
    }

    function getStakedAmount() external view override returns (Playa amount) {
        return getStakedAmountFor(msg.sender);
    }

    function getStakedToNodeAmount(NodeId node) external view override returns (Playa amount) {
        return getStakedToNodeAmountFor(node, msg.sender);
    }

    function getStakedNodes() external view override returns (NodeId[] memory stakedNodes) {
        return getStakedNodesFor(msg.sender);
    }

    // Public

    function claimFee(address payable to, Playa amount) public override {
        NodeId node = nodes.getNodeId(msg.sender);
        Playa balance = _getTotalBalance();
        _nodesFunds[node].claimFee(
            _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
            amount
        );
        _rootFund.remove(
            balance,
            FundLibrary.nodeToHolder(node),
            amount
        );
        emit FeeClaimed(node, to, amount);

        committee.updateWeight(node, Credit.unwrap(_rootFund.credits[FundLibrary.nodeToHolder(node)]));
        to.sendValue(Playa.unwrap(amount));
    }

    function getEarnedFeeAmount(NodeId node) public view override returns (Playa amount) {
        return _nodesFunds[node].getEarnedFee(
            _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node))
        );
    }

    function getStakedAmountFor(address holder) public view override returns (Playa amount) {
        uint256 nodesCount = _stakedNodes[holder].length();
        for (uint256 nodeIndex; nodeIndex < nodesCount; ++nodeIndex) {
            NodeId node = _stakedNodes[holder].at(nodeIndex);
            amount = amount + getStakedToNodeAmountFor(node, holder);
        }
    }

    function getStakedNodesFor(address holder) public view override returns (NodeId[] memory stakedNodes) {
        return _stakedNodes[holder].values();
    }

    function getStakedToNodeAmountFor(NodeId node, address holder) public view override returns (Playa amount) {
        Playa nodeBalance = _rootFund.getBalance(_getTotalBalance(), FundLibrary.nodeToHolder(node));
        return _nodesFunds[node].getBalance(
            nodeBalance,
            FundLibrary.addressToHolder(holder)
        );
    }

    // Private

    function _getTotalBalance() private view returns (Playa balance) {
        return Playa.wrap(address(this).balance);
    }
}
