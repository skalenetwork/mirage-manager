// SPDX-License-Identifier: AGPL-3.0-only

/*
    FairAccessManager.sol - fair-manager
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

import { AccessManagerUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

/**
 * @title FairAccessManager
 * @notice Manages access control roles for the fair manager contracts.
 */
contract FairAccessManager is AccessManagerUpgradeable {

    /// @notice Role for managing the Committee contract
    uint64 public constant COMMITTEE_ROLE = 1;
    /// @notice Role for managing the Nodes contract
    uint64 public constant NODES_ROLE = 2;
    /// @notice Role for managing the Staking contract
    uint64 public constant STAKING_ROLE = 3;
    /// @notice Role for managing the Status contract
    uint64 public constant STATUS_ROLE = 4;

    /**
     * @notice Initializes the FairAccessManager contract
     * @param initialAdmin The address of the initial admin
     */
    function initialize(address initialAdmin) public override initializer {
        __AccessManager_init(initialAdmin);
    }

}
