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

using {
    _creditAdd as +,
    _creditEqual as ==,
    _creditLess as <,
    _creditSubtract as -
} for Credit global;


/// @title Library for managing fund with fair tokens
/// @author Dmytro Stebaiev
/// @notice A holder can supply or retrieve fair tokens from the fund
/// Rewards can be sent to the fund and are shared among holders proportionally to their supply.abi
/// There is a dedicated owner that receive a fixed percentage of all rewards as a fee
library FundLibrary {
    using TypedMap for TypedMap.HolderToCreditMap;

    struct Fund {
        Fair lastBalance;
        Credit totalCredits;
        TypedMap.HolderToCreditMap credits;
        Credit ownerCredits;
        uint16 feeRate; // 0 - 1000‰
    }

    /// @notice Default number of credits to store 1 wei of fair tokens
    uint256 public constant CREDIT_PRECISION = 1 << 80;

    /// @notice Constant representing a null holder
    Holder public constant NULL = Holder.wrap(0);
    /// @notice Constant representing zero fair tokens
    Fair public constant ZERO_FAIR = Fair.wrap(0);
    /// @notice Constant representing zero credits
    Credit public constant ZERO_CREDIT = Credit.wrap(0);

    /// @notice Maximum allowed rounding error when moving fair tokens
    Fair private constant ALLOWED_ERROR = Fair.wrap(1e9);

    error NotEnoughStaked(Fair staked);
    error NotEnoughFee(Fair earnedFee);
    error RoundingErrorTooHigh(Fair roundingError);

    /// @notice Claims fee for the owner of the fund
    /// @param fund Fund struct
    /// @param balanceBeforeClaim Balance of the fund before claiming the fee
    /// @param amount Amount of fair tokens to claim as fee
    function claimFee(
        Fund storage fund,
        Fair balanceBeforeClaim,
        Fair amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeClaim);
        if (fund.feeRate > 0) {
            Credit credits = _toCreditsRoundedUp(fund, balanceBeforeClaim, amount);
            if (fund.ownerCredits < credits) {
                revert NotEnoughFee(_toFairRoundedDown(fund, balanceBeforeClaim, ZERO_CREDIT, fund.ownerCredits));
            }
            fund.ownerCredits = fund.ownerCredits - credits;
            fund.totalCredits = fund.totalCredits - credits;
            fund.lastBalance = balanceBeforeClaim - amount;
        }
    }

    /// @notice Withdraw fair tokens from the fund
    /// @param fund Fund struct
    /// @param balanceBeforeRemove Balance of the fund before removing fair tokens
    /// @param holder Holder of the fund that withdraws fair tokens
    /// @param amount Amount of fair tokens to withdraw
    function remove(
        Fund storage fund,
        Fair balanceBeforeRemove,
        Holder holder,
        Fair amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeRemove);
        Fair balanceBefore = getBalance(fund, balanceBeforeRemove, holder);
        Credit credits = _toCreditsRoundedUp(fund, balanceBeforeRemove, amount);
        _remove(fund, balanceBeforeRemove, holder, credits);
        Fair balanceAfter = getBalance(fund, fund.lastBalance, holder);
        _checkAllowedError(balanceBefore, balanceAfter, amount);
    }

    /// @notice Withdraws all fair tokens from the fund
    /// @param fund Fund struct
    /// @param balanceBeforeRemove Balance of the fund before removing fair tokens
    /// @param holder Holder of the fund that withdraws fair tokens
    /// @return removed Amount of fair tokens that were withdrawn
    function removeAll(
        Fund storage fund,
        Fair balanceBeforeRemove,
        Holder holder
    )
        internal
        returns (Fair removed)
    {
        _processBalanceChange(fund, balanceBeforeRemove);
        Fair balanceBefore = getBalance(fund, balanceBeforeRemove, holder);
        removed = _remove(fund, balanceBeforeRemove, holder, fund.credits.get(holder));
        Fair balanceAfter = getBalance(fund, fund.lastBalance, holder);
        _checkAllowedError(balanceBefore, balanceAfter, removed);
    }

    /// @notice Sets owner fee rate for the fund
    /// @param fund Fund struct
    /// @param balanceBefore Balance of the fund before setting the fee rate
    /// @param feeRate New fee rate to set (0 - 1000‰)
    function setFeeRate(
        Fund storage fund,
        Fair balanceBefore,
        uint16 feeRate
    )
        internal
    {
        _processBalanceChange(fund, balanceBefore);
        fund.feeRate = feeRate;
    }

    /// @notice Supplies fair tokens to the fund
    /// @param fund Fund struct
    /// @param balanceBeforeSupply Balance of the fund before supplying fair tokens
    /// @param holder Holder of the fund that supplies fair tokens
    /// @param amount Amount of fair tokens to supply
    function supply(
        Fund storage fund,
        Fair balanceBeforeSupply,
        Holder holder,
        Fair amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeSupply);
        Fair balanceBefore = getBalance(fund, balanceBeforeSupply, holder);
        Credit credits = _toCreditsRoundedDown(fund, balanceBeforeSupply, amount);
        (bool holderExists, Credit holderCredits) = fund.credits.tryGet(holder);
        // If holder does not exist, it is added with the credits.
        // If it does exist, set() must return false and value is updated.
        if (ZERO_CREDIT < credits) {
            assert(fund.credits.set(holder, holderCredits + credits) != holderExists);
            fund.totalCredits = fund.totalCredits + credits;
        }
        fund.lastBalance = balanceBeforeSupply + amount;
        Fair balanceAfter = getBalance(fund, fund.lastBalance, holder);
        _checkAllowedError(balanceBefore, balanceAfter, amount);
    }

    /// @notice Gets the balance of fair tokens for a holder in the fund
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    /// @param holder Holder of the fund to get the balance for
    /// @return amount Amount of fair tokens the holder has in the fund
    function getBalance(
        Fund storage fund,
        Fair balance,
        Holder holder
    )
        internal
        view
        returns (Fair amount)
    {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_FAIR;
        }
        (bool exists, Credit holderCredits) = fund.credits.tryGet(holder);
        // If exists credits is 0, otherwise it is not.
        assert(exists != (holderCredits == ZERO_CREDIT));
        return Fair.wrap(
            Math.mulDiv(
                Fair.unwrap(balance),
                Credit.unwrap(holderCredits),
                Credit.unwrap(fund.totalCredits + _getUncountedFeeCredits(fund, balance)),
                Math.Rounding.Floor
            )
        );
    }

    /// @notice Gets the earned fee for the owner of the fund
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    /// @return amount Amount of fair tokens the owner has earned as fee
    function getEarnedFee(
        Fund storage fund,
        Fair balance
    )
        internal
        view
        returns (Fair amount)
    {
        if (fund.feeRate > 0) {
            Credit uncountedFee = _getUncountedFeeCredits(fund, balance);
            return _toFairRoundedDown(fund, balance, uncountedFee, fund.ownerCredits + uncountedFee);
        }
    }

    /// @notice Cast Holder to address
    /// @param holder Holder to cast
    /// @return holderAddress holder as an address
    function holderToAddress(Holder holder) internal pure returns (address holderAddress) {
        return address(uint160(Holder.unwrap(holder)));
    }

    /// @notice Cast Holder to NodeId
    /// @param holder Holder to cast
    /// @return node holder as a NodeId
    function holderToNode(Holder holder) internal pure returns (NodeId node) {
        return NodeId.wrap(Holder.unwrap(holder));
    }

    /// @notice Cast address to Holder
    /// @param holder address to cast
    /// @return typedHolder the address as a Holder
    function addressToHolder(address holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(uint256(uint160(holder)));
    }

    /// @notice Cast NodeId to Holder
    /// @param holder NodeId to cast
    /// @return typedHolder the NodeId as a Holder
    function nodeToHolder(NodeId holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(NodeId.unwrap(holder));
    }

    // private

    /// @notice Processes balance change
    /// @dev Balance of the fund could be changed on protocol level without smart contract execution
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    function _processBalanceChange(
        Fund storage fund,
        Fair balance
    )
        private
    {
        if (fund.feeRate > 0 && balance > fund.lastBalance) {
            Credit credits = _getUncountedFeeCredits(fund, balance);
            fund.ownerCredits = fund.ownerCredits + credits;
            fund.totalCredits = fund.totalCredits + credits;
            fund.lastBalance = balance;
        }
    }

    /// @notice Removes fair tokens from the fund
    /// @param fund Fund struct
    /// @param balanceBeforeRemove Balance of the fund before removing fair tokens
    /// @param holder Holder of the fund that withdraws fair tokens
    /// @param amount Amount of credits to remove
    /// @return removed Amount of fair tokens that were withdrawn
    function _remove(
        Fund storage fund,
        Fair balanceBeforeRemove,
        Holder holder,
        Credit amount
    )
        private
        returns (Fair removed)
    {
        _processBalanceChange(fund, balanceBeforeRemove);
        (bool exists, Credit holderCredits) = fund.credits.tryGet(holder);
        if (holderCredits < amount) {
            revert NotEnoughStaked(_toFairRoundedDown(fund, balanceBeforeRemove, ZERO_CREDIT, holderCredits));
        }
        removed = _toFairRoundedDown(fund, balanceBeforeRemove, ZERO_CREDIT, amount);
        if (holderCredits == amount) {
            // Holders with Zero credits are always removed from the map.
            assert(fund.credits.remove(holder) == exists);
        }
        else {
            // Set must return false because holder already exists in the map.
            assert(!fund.credits.set(holder, holderCredits - amount));
        }

        fund.totalCredits = fund.totalCredits - amount;
        fund.lastBalance = balanceBeforeRemove - removed;
    }

    /// @notice Calculates uncounted fee credits based on the balance change
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    /// @return fee Amount of credits that represent the uncounted fee
    function _getUncountedFeeCredits(
        Fund storage fund,
        Fair balance
    )
        private
        view
        returns (Credit fee)
    {
        if (fund.feeRate > 0 && balance > fund.lastBalance) {
            Fair balanceChange = balance - fund.lastBalance;
            Fair feeInFair = Fair.wrap(
                Fair.unwrap(balanceChange) * fund.feeRate / 1000
            );
            return _toCreditsRoundedDown(fund, balance - feeInFair, feeInFair);
        }
        return ZERO_CREDIT;
    }

    /// @notice Calculate number of credits that correspond to the given amount of fair tokens
    /// @dev The value is rounded down
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    /// @param amount Amount of fair tokens to convert to credits
    /// @return credits Amount of credits that correspond to the given amount of fair tokens
    function _toCreditsRoundedDown(
        Fund storage fund,
        Fair balance,
        Fair amount
    )
        private
        view
        returns (Credit credits)
    {
        if (balance == ZERO_FAIR) {
            return Credit.wrap(Fair.unwrap(amount) * CREDIT_PRECISION);
        }
        return Credit.wrap(
            Math.mulDiv(
                Fair.unwrap(amount),
                Credit.unwrap(fund.totalCredits),
                Fair.unwrap(balance),
                Math.Rounding.Floor
            )
        );
    }

    /// @notice Calculate number of credits that correspond to the given amount of fair tokens
    /// @dev The value is rounded up
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    /// @param amount Amount of fair tokens to convert to credits
    /// @return credits Amount of credits that correspond to the given amount of fair tokens
    function _toCreditsRoundedUp(
        Fund storage fund,
        Fair balance,
        Fair amount
    )
        private
        view
        returns (Credit credits)
    {
        if (balance == ZERO_FAIR) {
            return Credit.wrap(Fair.unwrap(amount) * CREDIT_PRECISION);
        }
        return Credit.wrap(
            Math.mulDiv(
                Fair.unwrap(amount),
                Credit.unwrap(fund.totalCredits),
                Fair.unwrap(balance),
                Math.Rounding.Ceil
            )
        );
    }

    /// @notice Calculate number of fair tokens that correspond to the given amount of credits
    /// @dev The value is rounded down
    /// @param fund Fund struct
    /// @param balance Current balance of the fund
    /// @param uncountedFee Amount of uncounted fee credits that should be moved to the owner
    /// @param amount Amount of credits to convert to fair tokens
    /// @return fair Amount of fair tokens that correspond to the given amount of credits
    function _toFairRoundedDown(
        Fund storage fund,
        Fair balance,
        Credit uncountedFee,
        Credit amount
    )
        private
        view
        returns (Fair fair)
    {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_FAIR;
        }
        return Fair.wrap(
            Math.mulDiv(
                Fair.unwrap(balance),
                Credit.unwrap(amount),
                Credit.unwrap(fund.totalCredits + uncountedFee),
                Math.Rounding.Floor
            )
        );
    }

    /// @notice Checks that the rounding error is within the allowed limit
    /// @param balanceBefore Balance of the holder before the operation
    /// @param balanceAfter Balance of the holder after the operation
    /// @param amount Amount of fair tokens that were moved
    function _checkAllowedError(
        Fair balanceBefore,
        Fair balanceAfter,
        Fair amount
    )
        private
        pure
    {
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

/// @notice Adds two Credit values
/// @param a First Credit value
/// @param b Second Credit value
/// @return sum Sum of the two Credit values
function _creditAdd(Credit a, Credit b) pure returns (Credit sum) {
    return Credit.wrap(Credit.unwrap(a) + Credit.unwrap(b));
}

/// @notice Checks if two Credit values are equal
/// @param a First Credit value
/// @param b Second Credit value
/// @return equal True if the two Credit values are equal, false otherwise
function _creditEqual(Credit a, Credit b) pure returns (bool equal) {
    return Credit.unwrap(a) == Credit.unwrap(b);
}

/// @notice Checks if one Credit value is less than another
/// @param a First Credit value
/// @param b Second Credit value
/// @return less True if the first Credit value is less than the second, false otherwise
function _creditLess(Credit a, Credit b) pure returns (bool less) {
    return Credit.unwrap(a) < Credit.unwrap(b);
}

/// @notice Subtracts one Credit value from another
/// @param a First Credit value
/// @param b Second Credit value
/// @return diff Difference of the two Credit values
function _creditSubtract(Credit a, Credit b) pure returns (Credit diff) {
    return Credit.wrap(Credit.unwrap(a) - Credit.unwrap(b));
}
