// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   RewardWallet.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *   @author Eduardo Vasques
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
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {INodes, NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {IRewardWallet} from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import {IStaking} from "@skalenetwork/fair-manager-interfaces/IStaking.sol";

import {InvalidNodesAddress, InvalidStakingAddress} from "./utils/errors.sol";

/**
 * @title RewardWallet
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Manages reward collection and forwarding for individual FAIR nodes
 * @dev Receives rewards and forwards them to the Staking contract for the associated node
 */
contract RewardWallet is AccessManagedUpgradeable, IRewardWallet {
    using Address for address payable;

    /// @notice Reference to the Staking contract
    IStaking public staking;

    /// @notice Reference to the Nodes contract
    INodes public nodes;

    /// @notice The node ID that this wallet is associated with
    NodeId public ownerNode;

    /// @notice Thrown when attempting an operation that requires the owner node to exist
    error OwnerNodeDoesNotExist();

    /// @notice Thrown when receiving value would exceed the node's stake limit
    error ValueExceedsStakeLimit();

    /// @dev Ensures that the owner node exists
    modifier onlyIfNodeExists() {
        require(_nodeExists(ownerNode), OwnerNodeDoesNotExist());
        _;
    }

    /// @dev Ensures that receiving value wouldn't exceed the stake limit
    modifier onlyWithinStakeLimit() {
        require(staking.isWithinStakeLimit(ownerNode), ValueExceedsStakeLimit());
        _;
    }

    /**
     * @notice Fallback function to receive rewards
     * @dev Automatically flushes rewards to the Staking contract
     * @dev Only accepts funds if owner node exists and within stake limit
     */
    receive() external payable override onlyIfNodeExists onlyWithinStakeLimit {
        flush();
    }

    /**
     * @notice Initializes the RewardWallet contract
     * @dev This function is called only once during contract deployment following the proxy pattern
     * @param initialAuthority The address of the initial access control authority
     * @param staking_ The address of the Staking contract
     * @param nodes_ The address of the Nodes contract
     * @param ownerNode_ The node ID that this reward wallet is associated with
     */
    function initialize(address initialAuthority, IStaking staking_, INodes nodes_, NodeId ownerNode_)
        external
        override
        initializer
    {
        require(address(nodes_) != address(0), InvalidNodesAddress());
        require(address(staking_) != address(0), InvalidStakingAddress());
        __AccessManaged_init(initialAuthority);
        staking = staking_;
        ownerNode = ownerNode_;
        nodes = nodes_;
    }

    // Public

    /**
     * @notice Flushes all accumulated rewards to the Staking contract
     * @dev If owner node exists, rewards go to the node via staking.payReward()
     * @dev If owner node doesn't exist, rewards go to the Staking contract as network rewards (failsafe)
     */
    function flush() public override {
        if (address(this).balance > 0) {
            if (_nodeExists(ownerNode)) {
                // Both staking and ownerNode is set during deployment
                // by Staking contract so the warning is false positive
                // slither-disable-next-line arbitrary-send-eth
                staking.payReward{value: address(this).balance}(ownerNode);
            } else {
                // Rewards are sent as network rewards
                // This is a failsafe mechanism, it's expected to never happen under normal conditions
                payable(staking).sendValue(address(this).balance);
            }
        }
    }

    // Private

    /**
     * @notice Checks if an active node exists in the Nodes contract
     * @param nodeId The node ID to check
     * @return exists True if the node exists and is active, false otherwise
     */
    function _nodeExists(NodeId nodeId) private view returns (bool exists) {
        return nodes.activeNodeExists(nodeId);
    }
}
