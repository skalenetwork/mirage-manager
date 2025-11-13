
// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   constants.sol - fair-manager
 *   Copyright (C) 2025-Present SKALE Labs
 *   @author Dmytro Stebaiev
 *   @author Eduardo Vasques
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

/*
 * Central file for constants used across the project
 * Only non-trivial constants should be added here - i.e. values that may easily change over time
 */

// General constants

/// @dev Maximum number of iterations allowed for heavier loops
uint256 constant MAX_ITERATIONS = 2000;


// Field Operations

/// @dev Large prime number used for DKG cryptographic operations
uint256 constant LARGE_PRIME = 21888242871839275222246405745257275088696311157297823662689037894645226208583;


// Committee

/// @dev Default size of the committee
uint256 constant DEFAULT_COMMITTEE_SIZE = 22;
/// @dev Default delay for committee transitions
uint256 constant DEFAULT_TRANSITION_DELAY = 1 days;
/// @dev Minimum allowed transition delay - reasonable interval for off-chain components to react
uint256 constant DEFAULT_MIN_TRANSITION_DELAY = 10 minutes;


// Staking

/// @dev Default value for minimum stake amount required
uint256 constant DEFAULT_MIN_STAKE = 1 wei;
/// @dev Default waiting period until un-staked tokens can be claimed
uint256 constant DEFAULT_RETRIEVING_DELAY = 1 days;

// Fund

/// @dev Decimal precision for fee rates (0.0% - 100.0%)
uint16 constant FEE_RATE_PRECISION_VALUE = 1000;
/// @dev Allowed error margin for fund calculations (0.000000001 FAIR)
uint256 constant ALLOWED_ERROR = 1e9;


// Status

/// @dev Default interval for heartbeat checks
uint256 constant DEFAULT_HEARTBEAT_INTERVAL = 5 minutes;