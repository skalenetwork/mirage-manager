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

import {Test} from "../lib/forge-std/src/Test.sol";
import {CommitteeHandler} from "./handlers/CommitteeHandler.sol";
import {StakingHandler} from "./handlers/StakingHandler.sol";
import {StatusHandler} from "./handlers/StatusHandler.sol";


/**
 * @title IDefaultSetup
 * @author Eduardo Vasques
 * @notice Interface contract for DefaultSetup of Fair Manager tests
 */
interface IDefaultSetup {
    /// @notice Sets up the test environment
    function setUp() external;

    /**
     * @notice Returns the status handler
     * @return statusHandler The StatusHandler contract
     */
    function status() external view returns (StatusHandler statusHandler);

    /**
     * @notice Returns the committee handler
     * @return committeeHandler The committee handler address
     */
    function committee() external view returns (CommitteeHandler committeeHandler);

    /**
     * @notice Returns the staking handler
     * @return stakingHandler The staking handler address
     */
    function staking() external view returns (StakingHandler stakingHandler);
}

/**
 * @title Default Setup
 * @author Eduardo Vasques
 * @notice Contract with default setup for Fair Manager tests
 */
contract DefaultSetup is Test, IDefaultSetup {

    /// @inheritdoc IDefaultSetup
    StatusHandler public status;

    /// @inheritdoc IDefaultSetup
    CommitteeHandler public committee;

    /// @inheritdoc IDefaultSetup
    StakingHandler public staking;

    /// @inheritdoc IDefaultSetup
    /// @dev Reads from environment variables contract addresses and deploys handler contracts
    /// @dev Should be called by inheriting test contracts in their setUp() function
    function setUp() public virtual override {
        staking = new StakingHandler(payable(vm.envAddress("STAKING")), vm.envAddress("DEPLOYER"));
        status = new StatusHandler(vm.envAddress("STATUS"), vm.envAddress("DEPLOYER"));
        committee = new CommitteeHandler(payable(vm.envAddress("COMMITTEE")), vm.envAddress("DEPLOYER"));
    }
}