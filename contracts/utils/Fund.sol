// SPDX-License-Identifier: AGPL-3.0-only

/*
    Fund.sol - fair-manager
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

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {Fair} from "@skalenetwork/fair-manager-interfaces/units.sol";

import {TypedMap} from "../structs/typed/TypedMap.sol";
import {ALLOWED_ERROR, FEE_RATE_PRECISION_VALUE} from "./constants.sol";

/// @dev Represents credits in the fund system with high precision
type Credit is uint256;

/// @dev Represents a holder identifier that can be either an address or a node ID
type Holder is uint256;

using {_creditAdd as +, _creditEqual as ==, _creditLess as <, _creditSubtract as -} for Credit global;

/**
 * @title Fund Library
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Facilitates reward distribution and management operations in the FAIR network
 * @dev Implements a credit system for tracking proportional ownership in funds with fee management
 */
library FundLibrary {
    using TypedMap for TypedMap.HolderToCreditMap;

    /// @notice Struct representing fund state including balances, credits, and fee tracking
    struct Fund {
        Fair lastBalance;
        Credit totalCredits;
        TypedMap.HolderToCreditMap credits;
        Fair earnedFee;
        uint16 feeRate; // 0 - 1000‰
    }

    /// @notice Precision multiplier for credit calculations
    uint256 public constant CREDIT_PRECISION = 1 << 80;

    /// @notice Precision value for fee rate calculations
    uint16 public constant FEE_RATE_PRECISION = FEE_RATE_PRECISION_VALUE;

    /// @notice Null holder identifier constant
    Holder public constant NULL = Holder.wrap(0);

    /// @notice Zero FAIR token amount constant
    Fair public constant ZERO_FAIR = Fair.wrap(0);

    /// @notice Zero credit amount constant
    Credit public constant ZERO_CREDIT = Credit.wrap(0);

    /// @dev Indicates insufficient staked balance for a holder
    error NotEnoughStaked(Fair staked);

    /// @dev Indicates insufficient earned fees for the node owner
    error NotEnoughFee(Fair earnedFee);

    /// @dev Indicates a rounding error exceeds the allowed threshold
    error RoundingErrorTooHigh(Fair roundingError);

    /**
     * @notice Claims accumulated fees from the fund
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param amount Amount of fees to claim
     */
    function claimFee(Fund storage fund, Fair fundBalance, Fair amount) internal {
        _processBalanceChange(fund, fundBalance);

        if (fund.earnedFee < amount) {
            revert NotEnoughFee(fund.earnedFee);
        }
        fund.earnedFee = fund.earnedFee - amount;
        fund.lastBalance = fundBalance - amount;
    }

    /**
     * @notice Removes a specified amount from a holder's balance
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param holder The holder to remove funds from
     * @param amount Amount to remove
     */
    function remove(Fund storage fund, Fair fundBalance, Holder holder, Fair amount) internal {
        _processBalanceChange(fund, fundBalance);
        Fair holderBalance = getBalance(fund, fundBalance, holder);

        if (holderBalance == amount) {
            // Ensures no dust credits are left behind
            // Even if amount is zero
            _removeAll(fund, fundBalance, holder);
        } else if (amount > ZERO_FAIR) {
            Credit credits = _toCreditsRoundedUp(fund, fundBalance, amount);
            _remove(fund, fundBalance, holder, credits);
        } else {
            // amount is 0 and holder has balance
            // should not do anything
            return;
        }
        Fair balanceAfter = getBalance(fund, fund.lastBalance, holder);
        _checkAllowedError(holderBalance, balanceAfter, amount);
    }

    /**
     * @notice Sets the fee rate for the fund
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param feeRate New fee rate to set
     */
    function setFeeRate(Fund storage fund, Fair fundBalance, uint16 feeRate) internal {
        _processBalanceChange(fund, fundBalance);
        fund.feeRate = feeRate;
    }

    /**
     * @notice Adds funds to a holder's balance
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param holder The holder to add funds to
     * @param amount Amount to supply
     */
    function supply(Fund storage fund, Fair fundBalance, Holder holder, Fair amount) internal {
        _processBalanceChange(fund, fundBalance);
        Fair holderBalance = getBalance(fund, fundBalance, holder);
        Credit credits = _toCreditsRoundedDown(fund, fundBalance, amount);
        Fair delayedReward = ZERO_FAIR;
        if (fund.totalCredits == ZERO_CREDIT) {
            delayedReward = _getHoldersBalance(fund, fundBalance);
        }
        (bool holderExists, Credit holderCredits) = fund.credits.tryGet(holder);
        // If holder does not exist, it is added with the credits.
        // If it does exist, set() must return false and value is updated.
        if (ZERO_CREDIT < credits) {
            assert(fund.credits.set(holder, holderCredits + credits) != holderExists);
            fund.totalCredits = fund.totalCredits + credits;
        }
        fund.lastBalance = fundBalance + amount;
        Fair balanceAfter = getBalance(fund, fund.lastBalance, holder);
        _checkAllowedError(holderBalance, balanceAfter, amount + delayedReward);

        // Credits that result in zero balance are removed
        if (ZERO_CREDIT < credits && balanceAfter == ZERO_FAIR) {
            assert(fund.credits.remove(holder));
            fund.totalCredits = fund.totalCredits - credits;
        }
    }

    /**
     * @notice Updates the total balance of the fund and processes any balance changes
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     */
    function updateTotalBalance(Fund storage fund, Fair fundBalance) internal {
        _processBalanceChange(fund, fundBalance);
    }

    /**
     * @notice Retrieves the balance for a specific holder
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param holder The holder to query
     * @return amount The holder's balance
     */
    function getBalance(Fund storage fund, Fair fundBalance, Holder holder) internal view returns (Fair amount) {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_FAIR;
        }
        (bool exists, Credit holderCredits) = fund.credits.tryGet(holder);
        // If the holder does not exist, there should be no credits.
        assert(exists != (holderCredits == ZERO_CREDIT));
        return _toFairRoundedDown(fund, fundBalance, holderCredits);
    }

    /**
     * @notice Calculates total earned fees including uncounted fees
     * @param fund Storage reference to the fund
     * @param balance Current balance to calculate against
     * @return amount Total earned fees
     */
    function getEarnedFee(Fund storage fund, Fair balance) internal view returns (Fair amount) {
        return fund.earnedFee + _getUncountedFee(fund, balance);
    }

    /**
     * @notice Converts a Holder to an address
     * @param holder The holder identifier to convert
     * @return holderAddress The converted address
     */
    function holderToAddress(Holder holder) internal pure returns (address holderAddress) {
        return address(uint160(Holder.unwrap(holder)));
    }

    /**
     * @notice Converts a Holder to a NodeId
     * @param holder The holder identifier to convert
     * @return node The converted NodeId
     */
    function holderToNode(Holder holder) internal pure returns (NodeId node) {
        return NodeId.wrap(Holder.unwrap(holder));
    }

    /**
     * @notice Converts an address to a Holder
     * @param holder The address to convert
     * @return typedHolder The converted Holder identifier
     */
    function addressToHolder(address holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(uint256(uint160(holder)));
    }

    /**
     * @notice Converts a NodeId to a Holder
     * @param holder The NodeId to convert
     * @return typedHolder The converted Holder identifier
     */
    function nodeToHolder(NodeId holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(NodeId.unwrap(holder));
    }

    // private

    /**
     * @notice Processes balance changes and updates accrued fees
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     */
    function _processBalanceChange(Fund storage fund, Fair fundBalance) private {
        if (!(fundBalance == fund.lastBalance)) {
            if (fundBalance > fund.lastBalance) {
                fund.earnedFee = fund.earnedFee + _getUncountedFee(fund, fundBalance);
            }
            if (fund.earnedFee > fundBalance) {
                fund.earnedFee = fundBalance;
            }
            fund.lastBalance = fundBalance;
        }
    }

    /**
     * @notice Private function to remove ALL credits from a holder
     * @dev Calls _remove with the holder's total owned credits (if any)
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param holder The holder to remove credits from
     * @return removed Amount of FAIR tokens removed
     */
    function _removeAll(Fund storage fund, Fair fundBalance, Holder holder) private returns (Fair removed) {
        (bool exists, Credit holderCredits) = fund.credits.tryGet(holder);
        if (!exists) {
            return ZERO_FAIR;
        }
        removed = _remove(fund, fundBalance, holder, holderCredits);
    }

    /**
     * @notice Private function to remove credits from a holder
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param holder The holder to remove credits from
     * @param amount Amount of credits to remove
     * @return removed Amount of FAIR tokens removed
     */
    function _remove(Fund storage fund, Fair fundBalance, Holder holder, Credit amount) private returns (Fair removed) {
        (bool exists, Credit holderCredits) = fund.credits.tryGet(holder);
        if (holderCredits < amount) {
            revert NotEnoughStaked(_toFairRoundedDown(fund, fundBalance, holderCredits));
        }
        removed = _toFairRoundedDown(fund, fundBalance, amount);
        if (holderCredits == amount) {
            // Holders with Zero credits are always removed from the map.
            assert(fund.credits.remove(holder) == exists);
        } else {
            // Set must return false because holder already exists in the map.
            assert(!fund.credits.set(holder, holderCredits - amount));
        }

        fund.totalCredits = fund.totalCredits - amount;
        fund.lastBalance = fundBalance - removed;
    }

    /**
     * @notice Calculates the total balance that belongs to holders (total fund balance excluding fees)
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @return amount The holders' available balance
     */
    function _getHoldersBalance(Fund storage fund, Fair fundBalance) private view returns (Fair amount) {
        return fundBalance - (fund.earnedFee + _getUncountedFee(fund, fundBalance));
    }

    /**
     * @notice Calculates uncounted fees based on balance changes
     * @param fund Storage reference to the fund
     * @param balance Current balance to calculate against
     * @return fee The uncounted fee amount
     */
    function _getUncountedFee(Fund storage fund, Fair balance) private view returns (Fair fee) {
        if (balance > fund.lastBalance && fund.feeRate > 0) {
            Fair balanceChange = balance - fund.lastBalance;
            if (fund.totalCredits == ZERO_CREDIT) {
                // If there is no holders, all income goes to the owner.
                fee = balanceChange;
            } else {
                fee = Fair.wrap(Fair.unwrap(balanceChange) * fund.feeRate / FEE_RATE_PRECISION);
            }
            return fee;
        }
        return ZERO_FAIR;
    }

    /**
     * @notice Converts FAIR amount to credits rounded down
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param amount Amount of FAIR to convert
     * @return credits Converted credit amount
     */
    function _toCreditsRoundedDown(Fund storage fund, Fair fundBalance, Fair amount)
        private
        view
        returns (Credit credits)
    {
        Fair holdersBalance = _getHoldersBalance(fund, fundBalance);
        if (holdersBalance == ZERO_FAIR || fund.totalCredits == ZERO_CREDIT) {
            // If balance is positive but amount of shares is still zero.
            // Reward was received before somebody joined the fund.
            // Give away the reward to first holder joined because there is no one else.
            return Credit.wrap(Fair.unwrap(amount + holdersBalance) * CREDIT_PRECISION);
        }
        return Credit.wrap(
            Math.mulDiv(
                Credit.unwrap(fund.totalCredits), Fair.unwrap(amount), Fair.unwrap(holdersBalance), Math.Rounding.Floor
            )
        );
    }

    /**
     * @notice Converts FAIR amount to credits rounded up
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param amount Amount of FAIR to convert
     * @return credits Converted credit amount
     */
    function _toCreditsRoundedUp(Fund storage fund, Fair fundBalance, Fair amount)
        private
        view
        returns (Credit credits)
    {
        Fair holdersBalance = _getHoldersBalance(fund, fundBalance);
        if (holdersBalance == ZERO_FAIR || fund.totalCredits == ZERO_CREDIT) {
            // If balance is positive but amount of shares is still zero.
            // Reward was received before somebody joined the fund.
            // Give away the reward to first holder joined because there is no one else.
            return Credit.wrap(Fair.unwrap(amount + holdersBalance) * CREDIT_PRECISION);
        }
        return Credit.wrap(
            Math.mulDiv(
                Fair.unwrap(amount), Credit.unwrap(fund.totalCredits), Fair.unwrap(holdersBalance), Math.Rounding.Ceil
            )
        );
    }

    /**
     * @notice Converts credits to FAIR amount rounded down
     * @param fund Storage reference to the fund
     * @param fundBalance Current balance of the fund
     * @param amount Amount of credits to convert
     * @return fair Converted FAIR amount
     */
    function _toFairRoundedDown(Fund storage fund, Fair fundBalance, Credit amount) private view returns (Fair fair) {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_FAIR;
        }
        return Fair.wrap(
            Math.mulDiv(
                Fair.unwrap(_getHoldersBalance(fund, fundBalance)),
                Credit.unwrap(amount),
                Credit.unwrap(fund.totalCredits),
                Math.Rounding.Floor
            )
        );
    }

    /**
     * @notice Validates that rounding errors are within acceptable limits
     * @param balanceBefore Balance before the operation
     * @param balanceAfter Balance after the operation
     * @param amount The amount involved in the operation
     */
    function _checkAllowedError(Fair balanceBefore, Fair balanceAfter, Fair amount) private pure {
        Fair max = Fair.wrap(Math.max(Fair.unwrap(balanceBefore), Fair.unwrap(balanceAfter)));
        Fair min = Fair.wrap(Math.min(Fair.unwrap(balanceBefore), Fair.unwrap(balanceAfter)));
        Fair delta = max - min;

        max = Fair.wrap(Math.max(Fair.unwrap(delta), Fair.unwrap(amount)));
        min = Fair.wrap(Math.min(Fair.unwrap(delta), Fair.unwrap(amount)));

        Fair err = max - min;

        if (Fair.unwrap(err) > ALLOWED_ERROR) {
            // If the error is too high, we revert with a custom error
            // This is to prevent any potential exploits or issues with rounding errors
            // that could lead to funds lost.
            revert RoundingErrorTooHigh(err);
        }
    }
}

// operators

// Credit

/**
 * @notice Adds two credit amounts
 * @param a The first credit amount
 * @param b The second credit amount
 * @return sum The sum of the two credit amounts
 */
function _creditAdd(Credit a, Credit b) pure returns (Credit sum) {
    return Credit.wrap(Credit.unwrap(a) + Credit.unwrap(b));
}

/**
 * @notice Checks if two credit amounts are equal
 * @param a The first credit amount
 * @param b The second credit amount
 * @return equal True if the credit amounts are equal, false otherwise
 */
function _creditEqual(Credit a, Credit b) pure returns (bool equal) {
    return Credit.unwrap(a) == Credit.unwrap(b);
}

/**
 * @notice Checks if one credit amount is less than another
 * @param a The first credit amount
 * @param b The second credit amount
 * @return less True if a is less than b, false otherwise
 */
function _creditLess(Credit a, Credit b) pure returns (bool less) {
    return Credit.unwrap(a) < Credit.unwrap(b);
}

/**
 * @notice Subtracts two credit amounts
 * @param a The first credit amount
 * @param b The second credit amount
 * @return diff The result of subtracting b from a
 */
function _creditSubtract(Credit a, Credit b) pure returns (Credit diff) {
    return Credit.wrap(Credit.unwrap(a) - Credit.unwrap(b));
}
