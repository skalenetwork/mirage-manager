// SPDX-License-Identifier: AGPL-3.0-only

// cSpell:words twistb

/*
    G1Operations.sol - fair-manager
    Copyright (C) 2018-Present SKALE Labs

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

import { IDkg } from "@skalenetwork/fair-manager-interfaces/IDkg.sol";

import { Fp2Operations } from "./Fp2Operations.sol";

/**
 * @title G1Operations
 * @notice Library for operations on G1 elliptic curve points
 * @dev Provides functions for point validation, negation, and generator retrieval on the G1 elliptic curve.
 */
library G1Operations {

    using Fp2Operations for IDkg.Fp2Point;

    /**
     * @notice Retrieves the G1 generator point
     * @dev Returns the generator point of the G1 group.
     * @return generator The G1 generator point
     */
    function getG1Generator() internal pure returns (IDkg.Fp2Point memory generator) {
        // Current solidity version does not support Constants of non-value type
        // so we implemented this function
        return IDkg.Fp2Point({ a: 1, b: 2 });
    }

    /**
     * @notice Checks if the given coordinates form a valid G1 point
     * @dev Verifies the point satisfies the elliptic curve equation.
     * @param x The x-coordinate of the point
     * @param y The y-coordinate of the point
     * @return result True if the coordinates form a valid G1 point, false otherwise
     */
    function isG1Point(uint256 x, uint256 y) internal pure returns (bool result) {
        // Add an explicit check for the point at infinity, the identity element.
        if (x == 0 && y == 0) {
            return true;
        }
        uint256 p = Fp2Operations.P;
        return mulmod(y, y, p) == addmod(mulmod(mulmod(x, x, p), x, p), 3, p);
    }

    /**
     * @notice Checks if the given G1 point is valid
     * @dev Verifies the point satisfies the elliptic curve equation.
     * @param point The G1 point to check
     * @return result True if the point is valid, false otherwise
     */
    function isG1(IDkg.Fp2Point memory point) internal pure returns (bool result) {
        return isG1Point(point.a, point.b);
    }

    /**
     * @notice Checks if the given G1 point is within the valid range
     * @dev Verifies the coordinates of the point are less than the field prime.
     * @param point The G1 point to check
     * @return result True if the point is within the valid range, false otherwise
     */
    function checkRange(IDkg.Fp2Point memory point) internal pure returns (bool result) {
        return point.a < Fp2Operations.P && point.b < Fp2Operations.P;
    }

    /**
     * @notice Negates the y-coordinate of a G1 point
     * @dev Computes the modular negation of the y-coordinate.
     * @param y The y-coordinate to negate
     * @return result The negated y-coordinate
     */
    function negate(uint256 y) internal pure returns (uint256 result) {
        return (Fp2Operations.P - y) % Fp2Operations.P;
    }

}
