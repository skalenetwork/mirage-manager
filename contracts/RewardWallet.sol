// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   RewardWallet.sol - fair-manager
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
    Address
} from "@openzeppelin/contracts/utils/Address.sol";

import {INodes, NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {IRewardWallet} from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import {IStaking} from "@skalenetwork/fair-manager-interfaces/IStaking.sol";


contract RewardWallet is AccessManagedUpgradeable, IRewardWallet {
    using Address for address payable;

    IStaking public staking;
    INodes public nodes;
    NodeId public ownerNode;

    error OwnerNodeDoesNotExist();

    function initialize(
        address initialAuthority,
        IStaking staking_,
        INodes nodes_,
        NodeId ownerNode_
    )
        external
        override
        initializer
    {
        __AccessManaged_init(initialAuthority);
        staking = staking_;
        ownerNode = ownerNode_;
        nodes = nodes_;
    }

    receive() external payable override {
        require(
            _nodeExists(ownerNode),
            OwnerNodeDoesNotExist()
        );
        flush();
    }

    // Public

    function flush() public override {
        if (address(this).balance > 0) {
            if (_nodeExists(ownerNode)) {
                // Both staking and ownerNode is set during deployment
                // by Staking contract so the warning is false positive
                // slither-disable-next-line arbitrary-send-eth
                staking.payReward{value: address(this).balance}(ownerNode);
            }
            else {
                // Rewards are sent as network rewards
                // This is a failsafe mechanism, it's expected to never happen under normal conditions
                payable(staking).sendValue(address(this).balance);
            }

        }
    }

    // Private
    function _nodeExists(NodeId nodeId) private view returns (bool exists) {
        return nodes.activeNodeExists(nodeId);
    }
}
