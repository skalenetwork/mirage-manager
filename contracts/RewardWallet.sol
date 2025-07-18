// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   RewardWallet.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   fair-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   fair-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.8.24;

import {
    AccessManagedUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {NodeId} from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import {IRewardWallet} from "@skalenetwork/fair-manager-interfaces/IRewardWallet.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";


contract RewardWallet is AccessManagedUpgradeable, IRewardWallet {
    IStaking public staking;
    NodeId public ownerNode;

    function initialize(address initialAuthority, IStaking staking_, NodeId ownerNode_) external override initializer {
        __AccessManaged_init(initialAuthority);
        staking = staking_;
        ownerNode = ownerNode_;
    }

    receive() external payable override {
        flush();
    }

    // Public

    function flush() public override {
        if (address(this).balance > 0) {
            // Both staking and ownerNode is set during deployment
            // by Staking contract so the warning is false positive
            // slither-disable-next-line arbitrary-send-eth
            staking.payReward{value: address(this).balance}(ownerNode);
        }
    }
}
