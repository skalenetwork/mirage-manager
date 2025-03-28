// SPDX-License-Identifier: AGPL-3.0-only

/*
    PlayaAccessManager.sol - playa-manager
    Copyright (C) 2023-Present SKALE Labs
    @author Dmytro Stebaiev

    playa-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    playa-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with playa-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import {AccessManagerUpgradeable}
from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

// import {
//     IPlayaAccessManager
// } from "@skalenetwork/playa-manager-interfaces/contracts/IPlayaAccessManager.sol";


contract PlayaAccessManager is /*IPlayaAccessManager,*/ AccessManagerUpgradeable {
    function initialize(address initialAdmin) public initializer override {
        __AccessManager_init(initialAdmin);
    }
}
