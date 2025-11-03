// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   CommitteeTester.sol - fair-manager
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

import { Committee, ICommittee, NodeId, TypedSet } from "../Committee.sol";

/**
 * @title ICommitteeTester
 * @author SKALE Labs
 * @notice Interface for the CommitteeTester contract
 * @dev Extends ICommittee to add testing-specific functions
 */
interface ICommitteeTester is ICommittee {
    /**
     * @notice Checks if a node is present in the internal Red-Black Tree
     * @param node The node ID to check
     * @return result True if the node is in the RBTree, false otherwise
     */
    function isNodeInRBTree(NodeId node) external view returns (bool result);
}

/**
 * @title CommitteeTester
 * @author SKALE Labs
 * @notice Test harness for the Committee contract
 * @dev Exposes internal state for testing purposes
 */
contract CommitteeTester is Committee, ICommitteeTester {
    using TypedSet for TypedSet.NodeIdSet;

    /**
     * @notice Checks if a node is present in the internal Red-Black Tree
     * @dev Exposes the internal presentNodes set for state verification during testing
     * @param node The node ID to check
     * @return result True if the node is in the RBTree, false otherwise
     */
    function isNodeInRBTree(NodeId node) external view override returns (bool result) {
        return _pool.presentNodes.contains(node);
    }

}
