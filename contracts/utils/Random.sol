// SPDX-License-Identifier: AGPL-3.0-only

/*
    Random.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev
    @author Eduardo Vasques

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

import { IRandom } from "@skalenetwork/fair-manager-interfaces/IRandom.sol";

/**
 * @title Random Library
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Library for generating pseudo-random numbers using seed-based generation
 * @dev Provides utilities for creating random number generators and generating values
 * within specified ranges for weighted sampling and selection algorithms.
 */
library Random {

    /**
     * @notice Creates a RandomGenerator instance from a seed value
     * @param seed The initial seed value for random generation
     * @return generator The initialized RandomGenerator
     */
    function create(uint256 seed) internal pure returns (IRandom.RandomGenerator memory generator) {
        return IRandom.RandomGenerator({seed: seed});
    }

    /**
     * @notice Creates a RandomGenerator instance from entropy bytes
     * @param entropy The entropy bytes to hash into a seed
     * @return generator The initialized RandomGenerator
     */
    function createFromEntropy(
        bytes memory entropy
    )
        internal
        pure
        returns (IRandom.RandomGenerator memory generator)
    {
        return create(uint(keccak256(entropy)));
    }

    /**
     * @notice Generates a random value and updates the generator state
     * @param self The RandomGenerator instance (modified in place)
     * @return value The generated random uint256 value
     */
    function random(IRandom.RandomGenerator memory self) internal pure returns (uint256 value) {
        self.seed = uint256(sha256(abi.encodePacked(self.seed)));
        return self.seed;
    }

    /**
     * @notice Generates a random value in the range [0, max)
     * @param self The RandomGenerator instance (modified in place)
     * @param max The exclusive upper bound (must be greater than 0)
     * @return value The generated random value in range [0, max)
     */
    function random(
        IRandom.RandomGenerator memory self,
        uint256 max
    )
        internal
        pure
        returns (uint256 value)
    {
        assert(max > 0);
        uint256 maxRand = type(uint256).max - type(uint256).max % max;
        uint256 rand;
        do {
            rand = random(self);
        } while (!(rand < maxRand));
        return rand % max;
    }

    /**
     * @notice Generates a random value in the range [min, max)
     * @param self The RandomGenerator instance (modified in place)
     * @param min The inclusive lower bound
     * @param max The exclusive upper bound (must be greater than min)
     * @return value The generated random value in range [min, max)
     */
    function random(
        IRandom.RandomGenerator memory self,
        uint256 min,
        uint256 max
    )
        internal
        pure
        returns (uint256 value)
    {
        return random(self, max - min) + min;
    }
}
