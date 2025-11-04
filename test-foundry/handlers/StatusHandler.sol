// cspell:words Alives alives unshuffled
// SPDX-License-Identifier: AGPL-3.0-only

/*
    StatusHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs


    fair-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fair-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import {Duration, NodeId, Status} from "../../contracts/Status.sol";

import {Test} from "../../lib/forge-std/src/Test.sol";

/**
 * @title IStatusHandler
 * @author Eduardo Vasques
 * @notice Interface for the Status contract testing handler
 */
interface IStatusHandler {
    /**
     * @notice Whitelists a node from the fixtureNode list
     * @param nodeIndex Index into the fixture node array (modulo array length)
     */
    function whitelistNode(uint8 nodeIndex) external;

    /**
     * @notice Removes a node from the whitelist
     * @param nodeIndex Index into the fixture node array (modulo array length)
     */
    function removeNodeFromWhitelist(uint8 nodeIndex) external;

    /**
     * @notice Sends alive heartbeats from a random sample of nodes
     * @param numAlives Number of random nodes to send heartbeats (modulo fixture length)
     */
    function randomAlives(uint8 numAlives) external;

    /**
     * @notice Warps time to eject all unhealthy nodes, then sends heartbeats from a sample
     * @param numAlives Number of random nodes to send heartbeats after ejection
     */
    function alivesSomeWithAllEjected(uint8 numAlives) external;

    /**
     * @notice Warps time to make all nodes unhealthy, then sends heartbeats from all
     */
    function alivesAfterAllUnhealthy() external;

    /**
     * @notice Gets the Status contract instance
     * @return status The Status contract being tested
     */
    function status() external view returns (Status status);

    /**
     * @notice Gets a one of the registered nodes during deployment by index
     * @param index The index of the node in the fixture array
     * @return nodeId The NodeId at the specified index
     */
    function fixtureNode(uint256 index) external view returns (NodeId nodeId);

    /**
     * @notice Gets the admin address
     * @return admin The address with admin privileges
     */
    function admin() external view returns (address admin);
}
/**
 * @title Status Handler
 * @author Eduardo Vasques
 * @notice Handler contract for testing the Status contract
 */
contract StatusHandler is Test, IStatusHandler {
    /// @inheritdoc IStatusHandler
    Status public status;

    /// @inheritdoc IStatusHandler
    NodeId[] public fixtureNode;

    /// @inheritdoc IStatusHandler
    address public admin;

    error InvalidSamplingRequest();
    error StatusAddressNotSet();

    /**
     * @notice Constructor
     * @param _status The Status contract address
     * @param _admin The admin address
     */
    constructor(address _status, address _admin) {
        status = Status(_status);
        admin = _admin;
        require(address(_status) != address(0), StatusAddressNotSet());
        // scan first 256 active nodes
        for (uint256 i = 1; i < 257; ++i) {
            NodeId node = NodeId.wrap(i);
            if (status.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
    }

    /// @inheritdoc IStatusHandler
    function whitelistNode(uint8 nodeIndex) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(!status.isWhitelisted(node));
        address nodeOwner = status.nodes().getNode(node).nodeAddress;
        assert(nodeOwner != address(0));
        vm.prank(admin);
        status.whitelistNode(node);
        assert(status.isWhitelisted(node));
    }

    /// @inheritdoc IStatusHandler
    function removeNodeFromWhitelist(uint8 nodeIndex) public override {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(status.isWhitelisted(node));
        address nodeOwner = status.nodes().getNode(node).nodeAddress;
        assert(nodeOwner != address(0));
        vm.prank(admin);
        status.removeNodeFromWhitelist(node);
        assert(!status.isWhitelisted(node));
    }

    /// @inheritdoc IStatusHandler
    function randomAlives(uint8 numAlives) public override {
        uint256 alives = uint256(numAlives) % fixtureNode.length;
        uint256[] memory nodes = _getRandomSample(alives, fixtureNode.length);
        for (uint256 i = 0; i < alives; ++i) {
            address nodeOwner = status.nodes().getNode(NodeId.wrap(nodes[i])).nodeAddress;
            assert(nodeOwner != address(0));
            vm.prank(nodeOwner);
            status.alive();
        }
    }

    /// @inheritdoc IStatusHandler
    function alivesSomeWithAllEjected(uint8 numAlives) public override {
        uint256 numNodes = fixtureNode.length;

        uint256 alives = uint256(numAlives) % numNodes;
        uint256[] memory nodes = _getRandomSample(alives, numNodes);

        vm.warp(block.timestamp + 2 * Duration.unwrap(status.heartbeatInterval()));

        for (uint256 i = 0; i < numNodes; ++i) {
            status.committee().ejectUnhealthyNode();
        }
        for (uint256 i = 0; i < alives; ++i) {
            address nodeOwner = status.nodes().getNode(NodeId.wrap(nodes[i])).nodeAddress;
            assert(nodeOwner != address(0));
            vm.prank(nodeOwner);
            status.alive();
        }
    }

    /// @inheritdoc IStatusHandler
    function alivesAfterAllUnhealthy() public override {
        vm.warp(block.timestamp + 2 * Duration.unwrap(status.heartbeatInterval()));
        uint256 numNodes = fixtureNode.length;
        for (uint256 i = 0; i < numNodes; ++i) {
            address nodeOwner = status.nodes().getNode(fixtureNode[i]).nodeAddress;
            assert(nodeOwner != address(0));
            vm.prank(nodeOwner);
            status.alive();
        }
    }

    // Helpers

    /**
     * @notice Gets a pseudo-random sample of size `x` from the first `n` elements of fixtureNode
     * @param x Size of the random sample pretended
     * @param n Size of the original array
     * @return sample The random sample array
     * @dev `n` intentionally allows to control the subset of fixtureNode being sampled from
     */
    function _getRandomSample(
        uint256 x,
        uint256 n
    )
        private
        view
        returns (uint256[] memory sample)
    {
        // Handle edge cases
        if (x == 0) {
            return new uint256[](0);
        }

        // solhint-disable-next-line gas-strict-inequalities
        require(x <= n && n <= fixtureNode.length, InvalidSamplingRequest());

        // Create a copy to avoid modifying the original array
        uint256[] memory arr = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            arr[i] = NodeId.unwrap(fixtureNode[i]);
        }

        uint256[] memory arrCopy = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            arrCopy[i] = arr[i];
        }

        for (uint256 i = 0; i < x; ++i) {
            // Generate a random index from the unshuffled part of the array
            uint256 j = i + (uint256(keccak256(abi.encodePacked(block.timestamp, i))) % (n - i));

            // Swap the element at the random index `j` with the current element `i`
            uint256 temp = arrCopy[i];
            arrCopy[i] = arrCopy[j];
            arrCopy[j] = temp;
        }

        // Create the result array and copy the first X elements from the shuffled copy
        uint256[] memory result = new uint256[](x);
        for (uint256 i = 0; i < x; ++i) {
            result[i] = arrCopy[i];
        }

        return result;
    }
}