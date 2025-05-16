// SPDX-License-Identifier: AGPL-3.0-only

/*
    Fund.sol - mirage-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    mirage-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    mirage-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import { NodeId } from "@skalenetwork/professional-interfaces/INodes.sol";
import { Playa } from "@skalenetwork/professional-interfaces/units.sol";

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
        Playa lastBalance;
        Credit totalCredits;
        mapping (Holder holder => Credit share) credits;
        Credit ownerCredits;
        uint16 feeRate; // 0 - 1000‰
    }

    Holder public constant NULL = Holder.wrap(0);
    Playa public constant ZERO_PLAYA = Playa.wrap(0);
    Credit public constant ZERO_CREDIT = Credit.wrap(0);

    error NotEnoughStaked(Playa staked);
    error NotEnoughFee(Playa earnedFee);

    function claimFee(
        Fund storage fund,
        Playa balanceBeforeClaim,
        Playa amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeClaim);
        if (fund.feeRate > 0) {
            Credit credits = _toCredits(fund, balanceBeforeClaim, amount);
            if (fund.ownerCredits < credits) {
                revert NotEnoughFee(_toPlaya(fund, balanceBeforeClaim, ZERO_CREDIT, fund.ownerCredits));
            }
            fund.ownerCredits = fund.ownerCredits - credits;
            fund.totalCredits = fund.totalCredits - credits;
            fund.lastBalance = balanceBeforeClaim - amount;
        }
    }

    function remove(
        Fund storage fund,
        Playa balanceBeforeRemove,
        Holder holder,
        Playa amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeRemove);
        Credit credits = _toCredits(fund, balanceBeforeRemove, amount);
        if (fund.credits[holder] < credits) {
            revert NotEnoughStaked(_toPlaya(fund, balanceBeforeRemove, ZERO_CREDIT, fund.credits[holder]));
        }
        fund.credits[holder] = fund.credits[holder] - credits;
        fund.totalCredits = fund.totalCredits - credits;
        fund.lastBalance = balanceBeforeRemove - amount;
    }

    function setFeeRate(
        Fund storage fund,
        Playa balanceBefore,
        uint16 feeRate
    )
        internal
    {
        _processBalanceChange(fund, balanceBefore);
        fund.feeRate = feeRate;
    }

    function supply(
        Fund storage fund,
        Playa balanceBeforeSupply,
        Holder holder,
        Playa amount
    )
        internal
    {
        _processBalanceChange(fund, balanceBeforeSupply);
        Credit credits = _toCredits(fund, balanceBeforeSupply, amount);
        fund.credits[holder] = fund.credits[holder] + credits;
        fund.totalCredits = fund.totalCredits + credits;
        fund.lastBalance = balanceBeforeSupply + amount;
    }

    function getBalance(
        Fund storage fund,
        Playa balance,
        Holder holder
    )
        internal
        view
        returns (Playa amount)
    {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_PLAYA;
        }
        return Playa.wrap(
            Playa.unwrap(balance)
            * Credit.unwrap(fund.credits[holder])
            / Credit.unwrap(fund.totalCredits + _getUncountedFeeCredits(fund, balance))
        );
    }

    function getEarnedFee(
        Fund storage fund,
        Playa balance
    )
        internal
        view
        returns (Playa amount)
    {
        if (fund.feeRate > 0) {
            Credit uncountedFee = _getUncountedFeeCredits(fund, balance);
            return _toPlaya(fund, balance, uncountedFee, fund.ownerCredits + uncountedFee);
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
        Playa balance
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
        Playa balance
    )
        private
        view
        returns (Credit fee)
    {
        if (fund.feeRate > 0) {
            Playa balanceChange = balance - fund.lastBalance;
            Playa feeInPlaya = Playa.wrap(
                Playa.unwrap(balanceChange) * fund.feeRate / 1000
            );
            return _toCredits(fund, balance - feeInPlaya, feeInPlaya);
        }
        return ZERO_CREDIT;
    }

    function _toCredits(Fund storage fund, Playa balance, Playa amount) private view returns (Credit credits) {
        if (balance == ZERO_PLAYA) {
            return Credit.wrap(Playa.unwrap(amount));
        }
        return Credit.wrap(
            Playa.unwrap(amount) * Credit.unwrap(fund.totalCredits) / Playa.unwrap(balance)
        );
    }

    function _toPlaya(
        Fund storage fund,
        Playa balance,
        Credit uncountedFee,
        Credit amount
    )
        private
        view
        returns (Playa playa)
    {
        if (fund.totalCredits == ZERO_CREDIT) {
            return ZERO_PLAYA;
        }
        return Playa.wrap(
            Playa.unwrap(balance) * Credit.unwrap(amount) / Credit.unwrap(fund.totalCredits + uncountedFee)
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
