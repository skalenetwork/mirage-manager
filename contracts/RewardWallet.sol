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

import { AccessManagedUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { INodes, NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IRewardWallet } from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";

/**
 * @title RewardWallet
 * @notice A wallet for receiving rewards to nodes.
 */
contract RewardWallet is AccessManagedUpgradeable, IRewardWallet {

    using Address for address payable;

    /// @notice The Staking contract instance.
    IStaking public staking;
    /// @notice The Nodes contract instance.
    INodes public nodes;
    /// @notice The ID of the node that owns this reward wallet.
    NodeId public ownerNode;

    error OwnerNodeDoesNotExist();
    error ValueExceedsStakeLimit();

    modifier onlyIfNodeExists() {
        require(_nodeExists(ownerNode), OwnerNodeDoesNotExist());
        _;
    }

    modifier onlyWithinStakeLimit() {
        require(staking.isWithinStakeLimit(ownerNode), ValueExceedsStakeLimit());
        _;
    }

    /// @notice Receives Ether and flushes it to the staking contract.
    receive() external payable override onlyIfNodeExists onlyWithinStakeLimit {
        flush();
    }

    /**
     * @notice Initializes the RewardWallet contract.
     * @param initialAuthority The address of the initial authority.
     * @param staking_ The address of the Staking contract.
     * @param nodes_ The address of the Nodes contract.
     * @param ownerNode_ The ID of the node that the wallet corresponds to.
     */
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

    // Public

    /// @notice Flushes the entire balance of the wallet to the staking contract as a reward for the owner node.
    function flush() public override {
        if (address(this).balance > 0) {
            if (_nodeExists(ownerNode)) {
                // Both staking and ownerNode is set during deployment
                // by Staking contract so the warning is false positive
                // slither-disable-next-line arbitrary-send-eth
                staking.payReward{ value: address(this).balance }(ownerNode);
            } else {
                // Rewards are sent as network rewards
                // This is a failsafe mechanism, it's expected to never happen under normal conditions
                payable(staking).sendValue(address(this).balance);
            }
        }
    }

    // Private

    /**
     * @notice Checks if a node exists.
     * @param nodeId The ID of the node to check.
     * @return exists True if the node exists, false otherwise.
     */
    function _nodeExists(NodeId nodeId) private view returns (bool exists) {
        return nodes.activeNodeExists(nodeId);
    }

}
