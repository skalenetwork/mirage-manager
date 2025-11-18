// SPDX-License-Identifier: AGPL-3.0-only

// cspell:words: mixedcase

/*
    FairManagerFuzzDefaultSetup.t.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
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

import {StdInvariant} from "../lib/forge-std/src/StdInvariant.sol";

import {DefaultSetup} from "./DefaultSetup.sol";
import {Fair, NodeId} from "./handlers/StakingHandler.sol";

/**
 * @title IFairManagerFuzzDefaultSetup
 * @author Eduardo Vasques
 * @notice Interface for the Fair Manager fuzz testing contract
 */
interface IFairManagerFuzzDefaultSetup {
    // solhint-disable func-name-mixedcase
    /// @notice Core invariant check for the Fair Manager system
    function invariant_coreInvariants() external view;
    // solhint-enable func-name-mixedcase

    /// @notice Checks that all not whitelisted nodes are disabled in staking
    function checkNotWhitelistedAreDisabled() external view;

    /// @notice Validates staking contract balance consistency
    function checkStakingBalances() external view;
}

/**
 * @title Fair Manager Fuzz Default Setup
 * @author SKALE Labs
 * @notice Fuzz test contract with core invariants for the Fair Manager system
 */
contract FairManagerFuzzDefaultSetup is StdInvariant, DefaultSetup, IFairManagerFuzzDefaultSetup {
    error NodeShouldBeDisabled(NodeId node);
    error NotEnoughTokensInStaking(Fair calculated, Fair stakingBalance);
    error TotalDisabledHigherThanStakingBalance(Fair totalDisabled, Fair stakingBalance);
    error TotalDisabledDifferentFromSumOfDisabledStake(Fair totalDisabled, Fair sumOfDisabledStake);

    /// @notice Sets up the test environment
    function setUp() public override {
        super.setUp();
    }

    // solhint-disable func-name-mixedcase
    /// @inheritdoc IFairManagerFuzzDefaultSetup
    function invariant_coreInvariants() public view override {
        checkNotWhitelistedAreDisabled();
        checkStakingBalances();
    }

    // solhint-enable func-name-mixedcase

    /// @inheritdoc IFairManagerFuzzDefaultSetup
    function checkNotWhitelistedAreDisabled() public view override {
        uint256 numNodes = staking.getNumNodes();
        for (uint256 i = 0; i < numNodes; ++i) {
            NodeId node = staking.fixtureNode(i);
            if (!status.status().isWhitelisted(node)) {
                require(!staking.staking().isNodeEnabled(node), NodeShouldBeDisabled(node));
            }
        }
    }

    /// @inheritdoc IFairManagerFuzzDefaultSetup
    function checkStakingBalances() public view override {
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
        // TODO: FIX #247 - uncomment require
        //require(!(totalFees > totalStake), "Fees are higher than stake");
        uint256 stakingBalance = address(staking.staking()).balance;
        Fair minimumRequiredBalance = totalStake - walletsBalance + totalInExitQueue;

        // No real improvement seen when using strict inequalities for this particular case
        // solhint-disable gas-strict-inequalities
        require(
            Fair.unwrap(minimumRequiredBalance) <= stakingBalance,
            NotEnoughTokensInStaking(minimumRequiredBalance, Fair.wrap(stakingBalance))
        );

        require(
            Fair.unwrap(disabledStake) <= stakingBalance,
            TotalDisabledHigherThanStakingBalance(disabledStake, Fair.wrap(stakingBalance))
        );
        // solhint-enable gas-strict-inequalities

        require(
            disabledStake == staking.staking().totalDisabled(),
            TotalDisabledDifferentFromSumOfDisabledStake(disabledStake, staking.staking().totalDisabled())
        );
    }
}
