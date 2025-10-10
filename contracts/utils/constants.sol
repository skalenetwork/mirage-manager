
// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   constants.sol - fair-manager
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

/*
 * Central file for constants used across the project
 * Only non-trivial constants should be added here - i.e. values that may easily change over time
 */

// General constants

uint256 constant MAX_ITERATIONS = 2000; // reasonable number of iterations for heavier loops


// Field Operations

uint256 constant LARGE_PRIME = 21888242871839275222246405745257275088696311157297823662689037894645226208583;


// Committee

uint256 constant DEFAULT_COMMITTEE_SIZE = 22;
uint256 constant DEFAULT_TRANSITION_DELAY = 1 days;
uint256 constant DEFAULT_MIN_TRANSITION_DELAY = 10 minutes;


// Staking

uint256 constant DEFAULT_MIN_STAKE = 1 wei;
uint256 constant DEFAULT_RETRIEVING_DELAY = 1 days;

// Fund

uint16 constant FEE_RATE_PRECISION_VALUE = 1000; // Decimal precision for fees 0.0% - 100.0%
uint256 constant ALLOWED_ERROR = 1e9; // 0.000000001 FAIR


// Status

uint256 constant DEFAULT_HEARTBEAT_INTERVAL = 5 minutes;