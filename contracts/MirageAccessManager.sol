// SPDX-License-Identifier: AGPL-3.0-only

/*
    MirageAccessManager.sol - mirage-manager
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

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";


contract MirageAccessManager is AccessManagerUpgradeable {
    uint64 public constant NODES_ROLE = 1;
    uint64 public constant STATUS_ROLE = 2;
    uint64 public constant STAKING_ROLE = 3;

    function initialize(address initialAdmin) public initializer override {
        __AccessManager_init(initialAdmin);
    }
}
