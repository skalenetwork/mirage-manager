// SPDX-License-Identifier: AGPL-3.0-only

/*
    Fund.sol - fair-manager
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

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { Fair } from "@skalenetwork/fair-manager-interfaces/units.sol";

import { TypedMap } from "../structs/typed/TypedMap.sol";

type Credit is uint256;

type Holder is uint256;

using { _creditAdd as +, _creditEqual as ==, _creditLess as <, _creditSubtract as - } for Credit global;

/**
 * @title FundLibrary
 * @notice Library for managing funds with credits and fees
 */
library FundLibrary {

    using TypedMap for TypedMap.HolderToCreditMap;

    struct Fund {
        Fair lastBalance;
        Credit totalCredits;
        TypedMap.HolderToCreditMap credits;
        Fair earnedFee;
        uint16 feeRate; // 0 - 1000‰
    }

    /// @notice Precision used for credit calculations
    uint256 public constant CREDIT_PRECISION = 1 << 80;

    /// @notice Null holder constant
    Holder public constant NULL = Holder.wrap(0);

    /// @notice Zero Fair constant
    Fair public constant ZERO_FAIR = Fair.wrap(0);

    /// @notice Zero Credit constant
    Credit public constant ZERO_CREDIT = Credit.wrap(0);

    /// @dev Allowed error margin for rounding operations (maximum that is tolerated for a holder to 'lose')
    Fair private constant ALLOWED_ERROR = Fair.wrap(1e9);

    error NotEnoughStaked(Fair staked);
    error NotEnoughFee(Fair earnedFee);
    error RoundingErrorTooHigh(Fair roundingError);

    /**
     * @notice Removes 'amount' earned fees from the fund
     * @dev Process possible balance change and reduces the earned fee and fund's lastBalance by 'amount'.
     * @param fund The fund to claim the fee from
     * @param fundBalance The current balance of the fund
     * @param amount The amount of fee to claim
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
     * @notice Removes a specified amount from a holder's balance in the fund
     * @dev Updates the fund balance and credits, ensuring the holder has enough balance.
     * @param fund The fund to remove the amount from
     * @param fundBalance The current balance of the fund
     * @param holder The holder whose balance is to be reduced
     * @param amount The amount to remove
     */
    function remove(Fund storage fund, Fair fundBalance, Holder holder, Fair amount) internal {
        _processBalanceChange(fund, fundBalance);
        if (amount > ZERO_FAIR) {
            Fair holderBalance = getBalance(fund, fundBalance, holder);
            Credit credits;

            if (holderBalance == amount) {
                credits = fund.credits.get(holder);
            } else {
                credits = _toCreditsRoundedUp(fund, fundBalance, amount);
            }
            _remove(fund, fundBalance, holder, credits);
            Fair balanceAfter = getBalance(fund, fund.lastBalance, holder);
            _checkAllowedError(holderBalance, balanceAfter, amount);
        }
    }

    /**
     * @notice Sets the fee rate for the fund
     * @dev Processes a possible fundBalance change and assigns a new fee rate.
     * @param fund The fund to update
     * @param fundBalance The current balance of the fund
     * @param feeRate The new fee rate (0 - 1000‰)
     */
    function setFeeRate(Fund storage fund, Fair fundBalance, uint16 feeRate) internal {
        _processBalanceChange(fund, fundBalance);
        fund.feeRate = feeRate;
    }

    /**
     * @notice Supplies a specified amount to a holder's balance in the fund
     * @dev Updates the fund balance and credits, adding the amount to the holder's balance.
     * @param fund The fund to supply the amount to
     * @param fundBalance The current balance of the fund
     * @param holder The holder whose balance is to be increased
     * @param amount The amount to supply
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
     * @notice Updates the total balance of the fund
     * @dev Processes any changes in the fund balance.
     * @param fund The fund to update
     * @param fundBalance The current balance of the fund
     */
    function updateTotalBalance(Fund storage fund, Fair fundBalance) internal {
        _processBalanceChange(fund, fundBalance);
    }

    /**
     * @notice Retrieves the balance of a holder in the fund
     * @dev Calculates the holder's balance based on their credits and the fund's total balance
     * & asserts state consistency.
     *
     * @param fund The fund to query
     * @param fundBalance The current balance of the fund
     * @param holder The holder whose balance is to be retrieved
     * @return amount The balance of the holder
     */
    function getBalance(Fund storage fund, Fair fundBalance, Holder holder) internal view returns (Fair amount) {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_FAIR;
        }
        (bool exists, Credit holderCredits) = fund.credits.tryGet(holder);
        // If exists credits is 0, otherwise it is not.
        assert(exists != (holderCredits == ZERO_CREDIT));
        return _toFairRoundedDown(fund, fundBalance, holderCredits);
    }

    /**
     * @notice Retrieves the total earned fee of the fund
     * @dev Includes both the earned fee and any uncounted fee (fee accrued but not yet registered).
     * @param fund The fund to query
     * @param balance The current balance of the fund
     * @return amount The total earned fee
     */
    function getEarnedFee(Fund storage fund, Fair balance) internal view returns (Fair amount) {
        return fund.earnedFee + _getUncountedFee(fund, balance);
    }

    /**
     * @notice Converts a holder to an address
     * @param holder The holder to convert
     * @return holderAddress The address representation of the holder
     */
    function holderToAddress(Holder holder) internal pure returns (address holderAddress) {
        return address(uint160(Holder.unwrap(holder)));
    }

    /**
     * @notice Converts a holder to a NodeId
     * @param holder The holder to convert
     * @return node The NodeId representation of the holder
     */
    function holderToNode(Holder holder) internal pure returns (NodeId node) {
        return NodeId.wrap(Holder.unwrap(holder));
    }

    /**
     * @notice Converts an address to a holder
     * @param holder The address to convert
     * @return typedHolder The Holder representation of the address
     */
    function addressToHolder(address holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(uint256(uint160(holder)));
    }

    /**
     * @notice Converts a NodeId to a holder
     * @param holder The NodeId to convert
     * @return typedHolder The Holder representation of the NodeId
     */
    function nodeToHolder(NodeId holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(NodeId.unwrap(holder));
    }

    // private

    /**
     * @notice Processes changes in the fund balance
     * @dev Updates the earned fee and last balance based on the balance change.
     * @param fund The fund to update
     * @param fundBalance The current balance of the fund
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
     * @notice Removes a specified amount of credits from a holder
     * @dev Updates the fund balance and credits, ensuring the holder has enough credits.
     * @param fund The fund to update
     * @param fundBalance The current balance of the fund
     * @param holder The holder whose credits are to be reduced
     * @param amount The amount of credits to remove
     * @return removed The equivalent Fair value of the removed credits
     */
    function _remove(
        Fund storage fund,
        Fair fundBalance,
        Holder holder,
        Credit amount
    )
        private
        returns (Fair removed)
    {
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
     * @notice Retrieves the total balance of all holders in the fund
     * @dev Excludes from the totalBalance of the fund the earned fee and any uncounted fee.
     * @param fund The fund to query
     * @param fundBalance The current balance of the fund
     * @return amount The total balance of all holders
     */
    function _getHoldersBalance(Fund storage fund, Fair fundBalance) private view returns (Fair amount) {
        return fundBalance - (fund.earnedFee + _getUncountedFee(fund, fundBalance));
    }

    /**
     * @notice Calculates the uncounted fee in the fund
     * @dev Based on the balance change and fee rate.
     * @param fund The fund to query
     * @param balance The current balance of the fund
     * @return fee The uncounted fee
     */
    function _getUncountedFee(Fund storage fund, Fair balance) private view returns (Fair fee) {
        if (balance > fund.lastBalance && fund.feeRate > 0) {
            Fair balanceChange = balance - fund.lastBalance;
            if (fund.totalCredits == ZERO_CREDIT) {
                // If there is no holders, all income goes to the owner.
                fee = balanceChange;
            } else {
                fee = Fair.wrap(Fair.unwrap(balanceChange) * fund.feeRate / 1000);
            }
            return fee;
        }
        return ZERO_FAIR;
    }

    /**
     * @notice Converts a Fair amount to credits, rounding down
     * @dev Based on the fund's total credits and holders' balance.
     * @param fund The fund to query
     * @param fundBalance The current balance of the fund
     * @param amount The Fair amount to convert
     * @return credits The equivalent Credit value
     */
    function _toCreditsRoundedDown(
        Fund storage fund,
        Fair fundBalance,
        Fair amount
    )
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
     * @notice Converts a Fair amount to credits, rounding up
     * @dev Based on the fund's total credits and holders' balance.
     * @param fund The fund to query
     * @param fundBalance The current balance of the fund
     * @param amount The Fair amount to convert
     * @return credits The equivalent Credit value
     */
    function _toCreditsRoundedUp(
        Fund storage fund,
        Fair fundBalance,
        Fair amount
    )
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
     * @notice Converts credits to a Fair amount, rounding down
     * @dev Based on the fund's total credits and holders' balance.
     * @param fund The fund to query
     * @param fundBalance The current balance of the fund
     * @param amount The Credit amount to convert
     * @return fair The equivalent Fair value
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
     * @notice Checks if the rounding error is within the allowed limit
     * @dev Reverts if the error exceeds the allowed limit.
     * @param balanceBefore The balance before the operation
     * @param balanceAfter The balance after the operation
     * @param amount The amount involved in the operation
     */
    function _checkAllowedError(Fair balanceBefore, Fair balanceAfter, Fair amount) private pure {
        Fair max = Fair.wrap(Math.max(Fair.unwrap(balanceBefore), Fair.unwrap(balanceAfter)));
        Fair min = Fair.wrap(Math.min(Fair.unwrap(balanceBefore), Fair.unwrap(balanceAfter)));
        Fair delta = max - min;

        max = Fair.wrap(Math.max(Fair.unwrap(delta), Fair.unwrap(amount)));
        min = Fair.wrap(Math.min(Fair.unwrap(delta), Fair.unwrap(amount)));

        Fair err = max - min;

        if (err > ALLOWED_ERROR) {
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
 * @notice Adds two Credit values
 * @param a The first Credit value
 * @param b The second Credit value
 * @return sum The sum of the two Credit values
 */
function _creditAdd(Credit a, Credit b) pure returns (Credit sum) {
    return Credit.wrap(Credit.unwrap(a) + Credit.unwrap(b));
}

/**
 * @notice Checks if two Credit values are equal
 * @param a The first Credit value
 * @param b The second Credit value
 * @return equal True if the two Credit values are equal, false otherwise
 */
function _creditEqual(Credit a, Credit b) pure returns (bool equal) {
    return Credit.unwrap(a) == Credit.unwrap(b);
}

/**
 * @notice Checks if one Credit value is less than another
 * @param a The first Credit value
 * @param b The second Credit value
 * @return less True if the first Credit value is less than the second, false otherwise
 */
function _creditLess(Credit a, Credit b) pure returns (bool less) {
    return Credit.unwrap(a) < Credit.unwrap(b);
}

/**
 * @notice Subtracts one Credit value from another
 * @param a The Credit value to subtract from
 * @param b The Credit value to subtract
 * @return diff The difference between the two Credit values
 */
function _creditSubtract(Credit a, Credit b) pure returns (Credit diff) {
    return Credit.wrap(Credit.unwrap(a) - Credit.unwrap(b));
}
