// SPDX-License-Identifier: AGPL-3.0-only

/*
    FuzzyTestsWithDefaultSetup.t.sol - fair-manager
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

// 1. Import Foundry's standard test library
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {RootSetup} from "./Setup.sol";
import {Fair, NodeId} from "./handlers/StakingHandler.sol";

contract FuzzyTestsWithDefaultSetup is StdInvariant, RootSetup {

    // This function is called before each test case
    function setUp() public override{
        super.setUp();
    }

    function invariant_coreInvariants() public view {
        checkStakingBalances();
        checkBlacklistedAreDisabled();
    }

    function checkBlacklistedAreDisabled() public view {
        uint256 numNodes = staking.getNumNodes();
        for (uint256 i = 0; i < numNodes; ++i) {
            NodeId node = staking.fixtureNode(i);
            if (!status.status().isWhitelisted(node)){
                require(!staking.staking().isNodeEnabled(node), "Node should be disabled");
            }
        }
    }

    function checkStakingBalances() public view {
        uint256 numNodes = staking.getNumNodes();
        Fair totalStake;
        Fair walletsBalance;
        Fair disabledStake;
        Fair totalFees;
        Fair totalInExitQueue = staking.staking().getTotalInExitQueue();
        for (uint256 i = 0; i < numNodes; ++i) {
            NodeId node = staking.fixtureNode(i);
            Fair stake = staking.staking().getNodeTotalStake(node);
            if (stake > Fair.wrap(0)) {
                totalStake = totalStake + stake;
                address rewardWallet = address(staking.staking().getRewardWallet(node));
                walletsBalance = walletsBalance + Fair.wrap(rewardWallet.balance);
                if (!staking.staking().isNodeEnabled(node)) {
                    disabledStake = disabledStake + stake - Fair.wrap(rewardWallet.balance);
                }
                totalFees = totalFees + staking.staking().getEarnedFeeAmount(node);
            }
        }
        require(!(totalFees > totalStake), "Fees are higher than stake");
        require(
            Fair.unwrap(totalStake - walletsBalance + totalInExitQueue) <= address(staking.staking()).balance,
            "Not enought balance in staking"
        );
        require(
            Fair.unwrap(disabledStake) <= address(staking.staking()).balance,
            "Total Disabled is incorrect"
        );
        require(
            disabledStake == staking.staking().totalDisabled(),
            "Total Disabled is incorrect"
        );
    }
}