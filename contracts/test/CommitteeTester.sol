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

interface ICommitteeTester is ICommittee {
    function isNodeInRBTree(NodeId node) external view returns (bool result);
}

contract CommitteeTester is Committee, ICommitteeTester {
    using TypedSet for TypedSet.NodeIdSet;

    function isNodeInRBTree(NodeId node) external view override returns (bool result) {
        return _pool.presentNodes.contains(node);
    }

}
