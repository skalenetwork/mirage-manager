// SPDX-License-Identifier: AGPL-3.0-only

/*
    Random.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

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
 * @title Random
 * @notice Library for generating pseudo-random numbers
 */
library Random {

    /**
     * @notice Create an instance of RandomGenerator
     * @dev This function initializes a RandomGenerator with a given seed.
     * @param seed The initial seed value
     * @return generator A new RandomGenerator instance
     */
    function create(uint256 seed) internal pure returns (IRandom.RandomGenerator memory generator) {
        return IRandom.RandomGenerator({ seed: seed });
    }

    /**
     * @notice Create a RandomGenerator instance from entropy
     * @dev This function generates a seed from entropy bytes and initializes a RandomGenerator.
     * @param entropy The entropy bytes to generate the seed
     * @return generator A new RandomGenerator instance
     */
    function createFromEntropy(bytes memory entropy) internal pure returns (IRandom.RandomGenerator memory generator) {
        return create(uint256(keccak256(entropy)));
    }

    /**
     * @notice Generates a random value
     * @dev This function updates the seed and returns a pseudo-random value.
     * @param self The RandomGenerator instance
     * @return value A pseudo-random value
     */
    function random(IRandom.RandomGenerator memory self) internal pure returns (uint256 value) {
        self.seed = uint256(sha256(abi.encodePacked(self.seed)));
        return self.seed;
    }

    /**
     * @notice Generates a random value in the range [0, max)
     * @dev Ensures the generated value is within the specified range.
     * @param self The RandomGenerator instance
     * @param max The upper bound (exclusive)
     * @return value A pseudo-random value in the range [0, max)
     */
    function random(IRandom.RandomGenerator memory self, uint256 max) internal pure returns (uint256 value) {
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
     * @dev Calculates the range and ensures the value is within bounds.
     * @param self The RandomGenerator instance
     * @param min The lower bound (inclusive)
     * @param max The upper bound (exclusive)
     * @return value A pseudo-random value in the range [min, max)
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
