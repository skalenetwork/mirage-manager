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
import {ICommittee} from "@skalenetwork/professional-interfaces/ICommittee.sol";
import {INodes, NodeId} from "@skalenetwork/professional-interfaces/INodes.sol";
import {IStaking} from "@skalenetwork/professional-interfaces/IStaking.sol";
import {Nodes} from "./Nodes.sol";
import {NotImplemented} from "./utils/errors.sol";
import {FundLibrary, Playa} from "./utils/Fund.sol";


contract Staking is AccessManagedUpgradeable, IStaking {
    using FundLibrary for FundLibrary.Fund;

    ICommittee public committee;
    INodes public nodes;
    FundLibrary.Fund private _rootFund;
    mapping (NodeId node => FundLibrary.Fund nodeFund) private _nodesFunds;

    function initialize(address initialAuthority, ICommittee committee_, INodes nodes_) public initializer override {
        __AccessManaged_init(initialAuthority);
        committee = committee_;
        nodes = nodes_;
    }

    function stake(NodeId node) external payable override {
        require(nodes.activeNodeExists(node), Nodes.NodeDoesNotExist(node));
        Playa balance = Playa.wrap(address(this).balance - msg.value);
        Playa amount = Playa.wrap(msg.value);
        _rootFund.supply(
            balance,
            FundLibrary.nodeToHolder(node),
            amount
        );
        _nodesFunds[node].supply(
            _rootFund.getBalance(balance, FundLibrary.nodeToHolder(node)),
            FundLibrary.addressToHolder(msg.sender),
            amount
        );
    }

    function retrieve(NodeId /*node*/, uint256 /*value*/) external pure override {
        revert NotImplemented();
    }

    function getStakedAmount() external pure override returns (uint256 amount) {
        revert NotImplemented();
    }
}
