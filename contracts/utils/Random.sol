// SPDX-License-Identifier: AGPL-3.0-only

/*
    Random.sol - mirage-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    mirage-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    mirage-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with mirage-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import { IRandom } from "@skalenetwork/professional-interfaces/IRandom.sol";
import { Precompiled } from "./fieldOperations/Precompiled.sol";

/**
 * @title Random
 * @dev The library for generating of pseudo random numbers
 */
library Random {
    /**
     * @dev Retrieves randomSeed from rng
     */
    function randomSeed(address rng) internal view returns (uint256 seed) {
        return Precompiled.getRandomNumber(rng);
    }

    /**
     * @dev Create an instance of RandomGenerator
     */
    function create(uint256 seed) internal pure returns (IRandom.RandomGenerator memory generator) {
        return IRandom.RandomGenerator({seed: seed});
    }

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
     * @dev Generates random value
     */
    function random(IRandom.RandomGenerator memory self) internal pure returns (uint256 value) {
        self.seed = uint256(sha256(abi.encodePacked(self.seed)));
        return self.seed;
    }

    /**
     * @dev Generates random value in range [0, max)
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
     * @dev Generates random value in range [min, max)
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
