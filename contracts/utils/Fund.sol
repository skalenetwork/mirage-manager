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
    _creditEqual as ==
} for Credit global;

using {
    _holderNotEqual as !=
} for Holder global;


library FundLibrary {

    struct Fund {
        Playa lastBalance;
        Credit totalCredits;
        mapping (Holder holder => Credit share) credits;
        Holder owner;
        uint16 feeRate; // 0 - 1000‰
    }

    Holder public constant NULL = Holder.wrap(0);
    Playa public constant ZERO = Playa.wrap(0);
    Credit public constant ZERO_CREDIT = Credit.wrap(0);

    function supply(
        Fund storage fund,
        Playa balance,
        Holder holder,
        Playa amount
    )
        internal
    {
        _processBalanceChange(fund, balance);
        Credit credits = _toCredits(fund, balance, amount);
        fund.credits[holder] = fund.credits[holder] + credits;
        fund.totalCredits = fund.totalCredits + credits;
        fund.lastBalance = balance;
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
            return ZERO;
        }
        return Playa.wrap(
            Playa.unwrap(balance) * Credit.unwrap(fund.credits[holder]) / Credit.unwrap(fund.totalCredits)
        );
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
        if (balance > fund.lastBalance) {
            Playa balanceChange = balance - fund.lastBalance;
            fund.lastBalance = balance;
            if (fund.owner != NULL) {
                Playa fee = Playa.wrap(
                    Playa.unwrap(balanceChange) * fund.feeRate / 1000
                );
                supply(fund, balance, fund.owner, fee);
            }
        }
    }

    function _toCredits(Fund storage fund, Playa balance, Playa amount) private view returns (Credit credits) {
        if (balance == ZERO) {
            return Credit.wrap(Playa.unwrap(amount));
        }
        return Credit.wrap(
            Playa.unwrap(amount) * Credit.unwrap(fund.totalCredits) / Playa.unwrap(balance)
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

// Holder

function _holderNotEqual(Holder a, Holder b) pure returns (bool notEqual) {
    return Holder.unwrap(a) != Holder.unwrap(b);
}
