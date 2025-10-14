// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   errors.sol - fair-manager
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

import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";

/*
 * Central file for error messages used across the project
 */

/// @dev Address parameter is zero when it should not be
error AddressIsZero();

/// @dev The provided committee address is invalid
error InvalidCommitteeAddress();
/// @dev The provided nodes address is invalid
error InvalidNodesAddress();
/// @dev The provided staking address is invalid
error InvalidStakingAddress();
/// @dev The provided status address is invalid
error InvalidStatusAddress();

/// @dev The specified node does not exist
error NodeDoesNotExist(NodeId nodeId);
