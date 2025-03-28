// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   DKG.sol - playa-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *
 *   playa-manager is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   playa-manager is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with playa-manager.  If not, see <https://www.gnu.org/licenses/>.
 */

// cspell:words IDKG

pragma solidity ^0.8.24;

import { AccessManagedUpgradeable }
from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ICommittee} from "@skalenetwork/playa-manager-interfaces/contracts/ICommittee.sol";
import {DkgId, IDkg} from "@skalenetwork/playa-manager-interfaces/contracts/IDkg.sol";
import {INodes, NodeId} from "@skalenetwork/playa-manager-interfaces/contracts/INodes.sol";

import {NotImplemented} from "./errors.sol";


contract DKG is AccessManagedUpgradeable, IDkg {

    function initialize(address initialAuthority, ICommittee, INodes) public initializer {
        __AccessManaged_init(initialAuthority);
    }

    function alright(DkgId) external override {
        revert NotImplemented();
    }
    function broadcast(
        DkgId,
        G2Point[] calldata /*verificationVector*/,
        KeyShare[] calldata /*secretKeyContribution*/
    ) external override {
        revert NotImplemented();
    }
    function generate(NodeId[] calldata) external override returns (DkgId dkg) {
        revert NotImplemented();
    }
    function isNodeBroadcasted(DkgId, NodeId) external view override returns (bool broadcasted) {
        revert NotImplemented();
    }
}
