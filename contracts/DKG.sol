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

import {DKGId, IDKG} from "@skalenetwork/playa-manager-interfaces/contracts/IDKG.sol";
import {NotImplemented} from "./errors.sol";


contract DKG is IDKG {

    function alright() external override {
        revert NotImplemented();
    }
    function broadcast(
        G2Point[] calldata /*verificationVector*/,
        KeyShare[] calldata /*secretKeyContribution*/
    ) external override {
        revert NotImplemented();
    }
    function generate() external override returns (DKGId dkgId) {
        revert NotImplemented();
    }
}
