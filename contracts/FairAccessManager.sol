// SPDX-License-Identifier: AGPL-3.0-only

/*
    FairAccessManager.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev
    @author Eduardo Vasques

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

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

/**
 * @title FairAccessManager
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 *
 * @notice Manages role-based access control for the FAIR network contracts
 * @dev Extends OpenZeppelin's AccessManagerUpgradeable to define specific roles
 * for Committee, Nodes, Staking, and Status contracts. Each role controls access
 * to specific contract functions.
 */
contract FairAccessManager is AccessManagerUpgradeable {
    /// @notice Role ID for Committee contract operations
    uint64 public constant COMMITTEE_ROLE = 1;

    /// @notice Role ID for Nodes contract operations
    uint64 public constant NODES_ROLE = 2;

    /// @notice Role ID for Staking contract operations
    uint64 public constant STAKING_ROLE = 3;

    /// @notice Role ID for Status contract operations
    uint64 public constant STATUS_ROLE = 4;

    /**
     * @notice Initializes the FairAccessManager contract
     * @dev Sets up the initial admin with full access control privileges
     * @param initialAdmin The address that will be granted admin role
     */
    function initialize(address initialAdmin) public initializer override {
        __AccessManager_init(initialAdmin);
    }
}
