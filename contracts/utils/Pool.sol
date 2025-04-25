// SPDX-License-Identifier: AGPL-3.0-only

/*
    Random.sol - mirage-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    mirage-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    mirage-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import { NodeId } from "@skalenetwork/professional-interfaces/INodes.sol";
import {SplayTree} from "../structs/SplayTree.sol";
import {TypedSet} from "../structs/typed/TypedSet.sol";
import {NotImplemented} from "./errors.sol";


library PoolLibrary {
    using SplayTree for SplayTree.Node;
    using TypedSet for TypedSet.NodeIdSet;

    struct Pool {
        mapping (NodeId id => SplayTree.Node node) tree;
        NodeId root;
        TypedSet.NodeIdSet presentNodes;
        TypedSet.NodeIdSet incomingNodes;
    }

    error NodeIsMissing(NodeId id);

    function add(Pool storage pool, NodeId id) internal {
        assert(pool.incomingNodes.add(id));
    }

    function remove(Pool storage pool, NodeId node) internal {
        if (pool.presentNodes.remove(node)) {
            revert NotImplemented();
        } else {
            require(pool.incomingNodes.remove(node), NodeIsMissing(node));
        }
    }
}
