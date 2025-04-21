// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   Staking.sol - mirage-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   mirage-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   mirage-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IStaking} from "@skalenetwork/professional-interfaces/IStaking.sol";



contract Staking is AccessManagedUpgradeable, IStaking {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 public constant PRECISION = 1e10;
    EnumerableMap.AddressToUintMap private _userShares;
    uint256 public totalShares;
    error CannotStakeZeroTokens();
    error ErrorStakingTokens();
    error TransferFailed(address account, uint256 amount);
    error NotEnoughBalance(address account, uint256 amount);

    function initialize(address initialAuthority) public initializer override {
        __AccessManaged_init(initialAuthority);
        totalShares = 0;
    }

    function stake() external override payable {
        // Maybe also implement receive()
        require(msg.value > 0, CannotStakeZeroTokens());
        assert(_increaseShare(msg.sender, msg.value));
    }

    function retrieve(uint256 value) external override {
        require(!(_getStakedAmmount(msg.sender) < value), NotEnoughBalance(msg.sender, value));
        assert(!(value > address(this).balance));
        assert(_reduceShare(msg.sender, value));
        (bool success, ) = address(msg.sender).call{value: value}("");
        require(success, TransferFailed(msg.sender, value));
    }

    function getStakedAmount() external view override returns (uint256 amount) {
        amount = _getStakedAmmount(msg.sender);
    }

    function _increaseShare(address account, uint256 ammount) private returns (bool success) {
        uint256 balance = address(this).balance;
        uint256 accountShare = _userShares.get(account);
        if (balance == 0) {
            return _userShares.set(account, PRECISION);

        }
        uint256 update = (ammount * totalShares) / balance;
        uint256 newShare = accountShare + update;
        totalShares = totalShares + update;
        return _userShares.set(account, newShare);
    }
    function _reduceShare(address account, uint256 ammount) private returns (bool success) {
        uint256 balance = address(this).balance;
        if (balance == 0){
            return _userShares.set(account, 0);
        }
        uint256 accountShare = _userShares.get(account);
        uint256 update = (ammount * totalShares) / balance;
        uint256 newShare = accountShare - update;
        totalShares = totalShares - update;
        return _userShares.set(account, newShare);
    }

    function _getStakedAmmount(address account) private view returns (uint256 amount) {
        uint256 share = _userShares.get(account);
        if (share != 0) {
            uint256 balance = address(this).balance;
            amount = (balance * share) / totalShares;
        }
    }
}
