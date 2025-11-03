// SPDX-License-Identifier: AGPL-3.0-only

/*
    DefaultSetup.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs


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

import {Test} from "forge-std/Test.sol";

import {StatusHandler} from "./handlers/StatusHandler.sol";
import {CommitteeHandler} from "./handlers/CommitteeHandler.sol";
import {StakingHandler} from "./handlers/StakingHandler.sol";

contract DefaultSetup is Test {
    StatusHandler public status;
    CommitteeHandler public committee;
    StakingHandler public staking;

    function setUp() public virtual{
        staking = new StakingHandler(payable(vm.envAddress("STAKING")), vm.envAddress("DEPLOYER"));
        status = new StatusHandler(vm.envAddress("STATUS"), vm.envAddress("DEPLOYER"));
        committee = new CommitteeHandler(payable(vm.envAddress("COMMITTEE")), vm.envAddress("DEPLOYER"));
    }
}