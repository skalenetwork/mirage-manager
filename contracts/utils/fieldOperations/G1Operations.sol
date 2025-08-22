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


/// @title Library for operations with G1 points
/// @author Dmytro Stebaiev
/// @notice All operations are done in Fp2
library G1Operations {
    using Fp2Operations for IDkg.Fp2Point;

    /// @notice Gets the generator point of G1
    /// @return generator The Fp2 point representing the generator of G1
    function getG1Generator() internal pure returns (IDkg.Fp2Point memory generator) {
        // Current solidity version does not support Constants of non-value type
        // so we implemented this function
        return IDkg.Fp2Point({
            a: 1,
            b: 2
        });
    }

    /// @notice Checks if the given coordinates form a valid G1 point
    /// @param x The x-coordinate of the point in Fp2
    /// @param y The y-coordinate of the point in Fp2
    /// @return result True if the coordinates form a valid G1 point, false otherwise
    function isG1Point(uint256 x, uint256 y) internal pure returns (bool result) {
        uint256 p = Fp2Operations.P;
        return mulmod(y, y, p) ==
            addmod(mulmod(mulmod(x, x, p), x, p), 3, p);
    }

    /// @notice Checks if the given G1 point is valid
    /// @param point The G1 point to be checked
    /// @return result True if the G1 point is valid, false otherwise
    function isG1(IDkg.Fp2Point memory point) internal pure returns (bool result) {
        return isG1Point(point.a, point.b);
    }

    /// @notice Checks if the coordinates of the given Fp2 point are in the valid range
    /// @param point The Fp2 point to be checked
    /// @return result True if the coordinates are in the valid range, false otherwise
    function checkRange(IDkg.Fp2Point memory point) internal pure returns (bool result) {
        return point.a < Fp2Operations.P && point.b < Fp2Operations.P;
    }

    /// @notice Negates a coordinate in Fp2
    /// @param y The coordinate to be negated
    /// @return result The negated coordinate
    function negate(uint256 y) internal pure returns (uint256 result) {
        return (Fp2Operations.P - y) % Fp2Operations.P;
    }
}
