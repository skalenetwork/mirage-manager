// SPDX-License-Identifier: AGPL-3.0-only

/*
    Setup.sol - fair-manager
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

import {Test} from "forge-std/Test.sol";

// import handlers
import {StatusHandler} from "./handlers/StatusHandler.sol";
import {CommitteeHandler} from "./handlers/CommitteeHandler.sol";
import {StakingHandler} from "./handlers/StakingHandler.sol";


// Staked, whitelisted nodes
// If used on fork, this setup will whitelist all blacklisted nodes and stake some ETH to all active nodes before testing
// Recommend to change it if used on a fork to maintain state.
contract RootSetup is Test {
    StatusHandler public status;
    CommitteeHandler public committee;
    StakingHandler public staking;

    // This function is called before each test case
    function setUp() public virtual{
        // first Stake - setup sets some stake to nodes
        staking = new StakingHandler(payable(vm.envAddress("STAKING")), vm.envAddress("DEPLOYER"));
        // then Status - whitelisted and alive at start
        status = new StatusHandler(vm.envAddress("STATUS"), vm.envAddress("DEPLOYER"));
        committee = new CommitteeHandler(payable(vm.envAddress("COMMITTEE")));
        require(address(status) != address(0), "STATUS not set");
        require(address(committee) != address(0), "COMMITTEE not set");
        require(address(staking) != address(0), "STAKING not set");
    }
}