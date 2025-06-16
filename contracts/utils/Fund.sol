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
import { NodeId } from "@skalenetwork/fair-interfaces/INodes.sol";
import { Fair } from "@skalenetwork/fair-interfaces/units.sol";

type Credit is uint256;
type Holder is uint256;

using {
    _creditAdd as +,
    _creditEqual as ==,
    _creditLess as <,
    _creditSubtract as -
} for Credit global;


library FundLibrary {

    struct Fund {
        Fair lastBalance;
        Credit totalCredits;
        mapping (Holder holder => Credit share) credits;
        Credit ownerCredits;
        uint16 feeRate; // 0 - 1000‰
    }

    Holder public constant NULL = Holder.wrap(0);
    Fair public constant ZERO_FAIR = Fair.wrap(0);
    Credit public constant ZERO_CREDIT = Credit.wrap(0);

    error NotEnoughStaked(Fair staked);
    error NotEnoughFee(Fair earnedFee);

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

    function remove(
        Fund storage fund,
        Fair balanceBeforeRemove,
        Holder holder,
        Fair amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeRemove);
        Credit credits = _toCreditsRoundedUp(fund, balanceBeforeRemove, amount);
        if (fund.credits[holder] < credits) {
            revert NotEnoughStaked(_toFairRoundedDown(fund, balanceBeforeRemove, ZERO_CREDIT, fund.credits[holder]));
        }
        fund.credits[holder] = fund.credits[holder] - credits;
        fund.totalCredits = fund.totalCredits - credits;
        fund.lastBalance = balanceBeforeRemove - amount;
    }

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

    function supply(
        Fund storage fund,
        Fair balanceBeforeSupply,
        Holder holder,
        Fair amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeSupply);
        Credit credits = _toCreditsRoundedDown(fund, balanceBeforeSupply, amount);
        fund.credits[holder] = fund.credits[holder] + credits;
        fund.totalCredits = fund.totalCredits + credits;
        fund.lastBalance = balanceBeforeSupply + amount;
    }

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
        return Fair.wrap(
            Fair.unwrap(balance)
            * Credit.unwrap(fund.credits[holder])
            / Credit.unwrap(fund.totalCredits + _getUncountedFeeCredits(fund, balance))
        );
    }

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


    function addressToHolder(address holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(uint256(uint160(holder)));
    }

    function nodeToHolder(NodeId holder) internal pure returns (Holder typedHolder) {
        return Holder.wrap(NodeId.unwrap(holder));
    }

    // private

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
            return Credit.wrap(Fair.unwrap(amount));
        }
        return Credit.wrap(
            Fair.unwrap(amount) * Credit.unwrap(fund.totalCredits) / Fair.unwrap(balance)
        );
    }

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
            return Credit.wrap(Fair.unwrap(amount));
        }
        return Credit.wrap(
            Math.ceilDiv(
                Fair.unwrap(amount) * Credit.unwrap(fund.totalCredits),
                Fair.unwrap(balance)
            )
        );
    }

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
            Fair.unwrap(balance) * Credit.unwrap(amount) / Credit.unwrap(fund.totalCredits + uncountedFee)
        );
    }
}

// operators

// Credit

function _creditAdd(Credit a, Credit b) pure returns (Credit sum) {
    return Credit.wrap(Credit.unwrap(a) + Credit.unwrap(b));
}

function _creditEqual(Credit a, Credit b) pure returns (bool equal) {
    return Credit.unwrap(a) == Credit.unwrap(b);
}

function _creditLess(Credit a, Credit b) pure returns (bool less) {
    return Credit.unwrap(a) < Credit.unwrap(b);
}

function _creditSubtract(Credit a, Credit b) pure returns (Credit diff) {
    return Credit.wrap(Credit.unwrap(a) - Credit.unwrap(b));
}
