// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Nodes.sol - playa-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   playa-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   playa-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with playa-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {INodes, NodeId} from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";
import {NotImplemented} from "./errors.sol";


contract Nodes is AccessManagedUpgradeable, INodes {
    // TODO: remove
    uint256 public constant REMOVE = 5;

    function initialize(address initialAuthority) public initializer {
        __AccessManaged_init(initialAuthority);
    }

    function registerNode(
        bytes calldata /* ip */,
        uint16 /* port */
    ) external override restricted {
        revert NotImplemented();
    }

    function registerPassiveNode(
        bytes calldata /* ip */,
        uint16 /* port */
    ) external override {
        revert NotImplemented();
    }

    function setIpAddress(NodeId, bytes calldata, uint16) external override {
        revert NotImplemented();
    }

    function setDomainName(NodeId, string calldata) external {
        revert NotImplemented();
    }

    function requestChangeAddress(NodeId, address) external override {
        revert NotImplemented();
    }

    function confirmAddressChange(NodeId) external override {
        revert NotImplemented();
    }

    function getNode(NodeId /* nodeId */) external view override returns (Node memory node) {
        revert NotImplemented();
    }

    function getNodeId(address) external view override returns (NodeId nodeId) {
        revert NotImplemented();
    }
}
