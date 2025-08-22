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
 * @author Dmytro Stebaiev
 * @notice The library for generating of pseudo random numbers
 */
library Random {

    /**
     * @notice Create an instance of RandomGenerator
     * @param seed Initial seed
     * @return generator Instance of RandomGenerator
     */
    function create(uint256 seed) internal pure returns (IRandom.RandomGenerator memory generator) {
        return IRandom.RandomGenerator({seed: seed});
    }

    /**
     * @notice Create an instance of RandomGenerator from entropy
     * @param entropy Entropy bytes
     * @return generator Instance of RandomGenerator
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
     * @notice Generates random value
     * @dev Returns value from 0 to type(uint256).max
     * @param self Instance of RandomGenerator
     * @return value Random value
     */
    function random(IRandom.RandomGenerator memory self) internal pure returns (uint256 value) {
        self.seed = uint256(sha256(abi.encodePacked(self.seed)));
        return self.seed;
    }

    /**
     * @notice Generates random value in range [0, max)
     * @param self Instance of RandomGenerator
     * @param max Upper bound (exclusive)
     * @return value Random value
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
     * @notice Generates random value in range [min, max)
     * @param self Instance of RandomGenerator
     * @param min Lower bound (inclusive)
     * @param max Upper bound (exclusive)
     * @return value Random value
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
