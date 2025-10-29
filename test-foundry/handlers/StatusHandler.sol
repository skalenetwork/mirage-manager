// cspell:words Alives alives unshuffled
// SPDX-License-Identifier: AGPL-3.0-only

/*
    StatusHandler.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

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

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

import {Test} from "forge-std/Test.sol";

import {Duration, NodeId, Status} from "../../contracts/Status.sol";
import {Fair} from "../../contracts/utils/Fund.sol";

contract StatusHandler is Test {

    Status public status;
    NodeId[] public fixtureNode;
    address public admin;

    uint256 private constant PRECISION = 1_000_000_000_000_000_000;

    error GasCalculationError(uint256 calculatedGas);

    constructor(address _status, address _admin) {
        status = Status(_status);
        admin = _admin;
        require(address(status) != address(0), "STATUS not set");
        // scan first 256 active nodes
        for (uint256 i = 1; i < 257; i++) {
            NodeId node = NodeId.wrap(i);
            if (status.nodes().activeNodeExists(node)) {
                fixtureNode.push(node);
            }
        }
    }

    function whitelistNode(uint8 nodeIndex) public {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(!status.isWhitelisted(node));
        address nodeOwner = status.nodes().getNode(node).nodeAddress;
        assert(nodeOwner != address(0));
        vm.prank(admin);
        status.whitelistNode(node);
        assert(status.isWhitelisted(node));
    }

    function blacklistNode(uint8 nodeIndex) public {
        NodeId node = fixtureNode[nodeIndex % fixtureNode.length];
        vm.assume(status.isWhitelisted(node));
        address nodeOwner = status.nodes().getNode(node).nodeAddress;
        assert(nodeOwner != address(0));
        vm.prank(admin);
        status.removeNodeFromWhitelist(node);
        assert(!status.isWhitelisted(node));
    }

    function randomAlives(uint8 numAlives) public {
        uint256 alives = uint256(numAlives) % fixtureNode.length;
        uint256[] memory nodes = _getRandomSample(alives, fixtureNode.length);
        for (uint256 i = 0; i < alives; i++) {
            address nodeOwner = status.nodes().getNode(NodeId.wrap(nodes[i])).nodeAddress;
            assert(nodeOwner != address(0));
            uint256 gas = _customGas();
            vm.prank(nodeOwner);
            status.alive{gas: gas}();
        }
    }

    function alivesSomeWithAllEjected(uint256 numAlives) public {
        uint256 alives = uint256(numAlives) % fixtureNode.length;
        uint256[] memory nodes = _getRandomSample(alives, fixtureNode.length);

        vm.warp(block.timestamp + 2 * Duration.unwrap(status.heartbeatInterval()));

        for (uint256 i = 0; i < fixtureNode.length; i++) {
            status.committee().ejectUnhealthyNode();
        }
        for (uint256 i = 0; i < alives; i++) {
            address nodeOwner = status.nodes().getNode(NodeId.wrap(nodes[i])).nodeAddress;
            assert(nodeOwner != address(0));
            uint256 gas = _customGas();
            vm.prank(nodeOwner);
            status.alive{gas: gas}();
        }
    }

    function alivesAfterAllUnhealthy() public {
        vm.warp(block.timestamp + 2 * Duration.unwrap(status.heartbeatInterval()));
        for (uint256 i = 0; i < fixtureNode.length; i++) {
            address nodeOwner = status.nodes().getNode(fixtureNode[i]).nodeAddress;
            assert(nodeOwner != address(0));
            uint256 gas = _customGas();
            vm.prank(nodeOwner);
            status.alive{gas: gas}();
        }
    }

    // Helpers

    function _getRandomSample(
        uint256 x,
        uint256 n
    )
        private
        view
        returns (uint256[] memory)
    {
        // Handle edge cases
        if (x == 0) {
            return new uint256[](0);
        }
        if (x > n) {
            revert("Sample size cannot be larger than the array length.");
        }

        // Create a copy to avoid modifying the original array
        uint256[] memory arr = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            arr[i] = NodeId.unwrap(fixtureNode[i]);
        }

        uint256[] memory arrCopy = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            arrCopy[i] = arr[i];
        }

        for (uint256 i = 0; i < x; i++) {
            // Generate a random index from the unshuffled part of the array
            uint256 j = i + (uint256(keccak256(abi.encodePacked(block.timestamp, i))) % (n - i));

            // Swap the element at the random index `j` with the current element `i`
            uint256 temp = arrCopy[i];
            arrCopy[i] = arrCopy[j];
            arrCopy[j] = temp;
        }

        // Create the result array and copy the first X elements from the shuffled copy
        uint256[] memory result = new uint256[](x);
        for (uint256 i = 0; i < x; i++) {
            result[i] = arrCopy[i];
        }

        return result;
    }


    function _customGas() private view returns (uint256 gas) {
        NodeId[] memory activeNodes = status.nodes().getActiveNodeIds();
        uint256 num_nodes = 0;
        for (uint256 i = 0; i < activeNodes.length; i++) {
            if (status.isWhitelisted(activeNodes[i])) {
                num_nodes++;
            }
        }
        gas = (((230000 * _log10(num_nodes + 15) + 520000*PRECISION) * 12) / 10) / PRECISION;
    }

    /// @dev Returns only integer size, so it's underestimating log10.
    function _log10(uint256 x) private pure returns (uint256) {
        require(x > 0, "log10: input must be greater than 0");

        // ln(10) * 10**18
        uint256 LN10_SCALED = 2_302_585_092_994_045_684;

        // WAD constant (10**18)
        uint256 WAD = 10**18;

        require(x <= uint256(type(int256).max) / WAD, "Log: Input too large");
        int256 x_signed = int256(x * WAD);

        int256 ln_x_signed = FixedPointMathLib.lnWad(x_signed);

        uint256 ln_x = uint256(ln_x_signed);

        // this will give us log10(x) * 10**18
        return (ln_x * PRECISION) / LN10_SCALED;
    }
}