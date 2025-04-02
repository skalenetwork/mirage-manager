// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Status.sol - playa-manager
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
import {
    Duration,
    IStatus
} from "@skalenetwork/playa-manager-interfaces/contracts/IStatus.sol";

import {NotImplemented} from "./errors.sol";


contract Status is AccessManagedUpgradeable, IStatus {
    function initialize(address initialAuthority, INodes) public initializer override {
        __AccessManaged_init(initialAuthority);
    }
    function alive() external override {
        revert NotImplemented();
    }
    function setHeartbeatInterval(Duration /*interval*/) external override {
        revert NotImplemented();
    }
    function whitelistNode(NodeId) external override {
        revert NotImplemented();
    }
    function removeNodeFromWhitelist(NodeId) external override {
        revert NotImplemented();
    }
    function isHealthy(NodeId /*nodeId*/) external view override returns (bool healthy) {
        revert NotImplemented();
    }
    function getNodesEligibleForCommittee() external view override returns (NodeId[] memory nodeIds) {
        revert NotImplemented();
    }
    function getWhitelistedNodes() external view override returns (uint256[] memory nodeIds) {
        revert NotImplemented();
    }
}
