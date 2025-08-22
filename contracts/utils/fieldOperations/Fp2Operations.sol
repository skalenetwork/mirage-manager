// SPDX-License-Identifier: AGPL-3.0-only

// cSpell:words twistb

/*
    Fp2Operations.sol - fair-manager
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

import { Precompiled } from "../Precompiled.sol";


/// @title Library for operations in Fp2 field
/// @notice Provides functions for addition, multiplication, inversion, and comparison of Fp2 points
/// @author Dmytro Stebaiev
library Fp2Operations {

    /// @notice The prime number defining the field Fp
    uint256 constant public P =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    /// @notice Computes the multiplicative inverse of an Fp2 point
    /// @param value The Fp2 point to invert
    /// @return result The multiplicative inverse of the input Fp2 point
    function inverseFp2(
        IDkg.Fp2Point memory value
    )
        internal
        view
        returns (IDkg.Fp2Point memory result)
    {
        uint256 p = P;
        uint256 t0 = mulmod(value.a, value.a, p);
        uint256 t1 = mulmod(value.b, value.b, p);
        uint256 t2 = mulmod(p - 1, t1, p);
        if (t2 < t0) {
            t2 = (p - addmod(t2, p - t0, p)) % p;
        } else {
            t2 = addmod(t0, p - t2, p);
        }
        uint256 t3 = Precompiled.bigModExp(t2, p - 2, p);
        result.a = mulmod(value.a, t3, p);
        result.b = (p - mulmod(value.b, t3, p)) % p;
    }

    /// @notice Adds two Fp2 points
    /// @param value1 The first Fp2 point
    /// @param value2 The second Fp2 point
    /// @return result The sum of the two Fp2 points
    function addFp2(IDkg.Fp2Point memory value1, IDkg.Fp2Point memory value2)
        internal
        pure
        returns (IDkg.Fp2Point memory result)
    {
        return IDkg.Fp2Point({
            a: addmod(value1.a, value2.a, P),
            b: addmod(value1.b, value2.b, P)
        });
    }

    /// @notice Multiplies an Fp2 point by a scalar
    /// @param value The Fp2 point to be multiplied
    /// @param scalar The scalar to multiply the Fp2 point by
    /// @return result The result of the scalar multiplication
    function scalarMulFp2(IDkg.Fp2Point memory value, uint256 scalar)
        internal
        pure
        returns (IDkg.Fp2Point memory result)
    {
        return IDkg.Fp2Point({ a: mulmod(scalar, value.a, P), b: mulmod(scalar, value.b, P) });
    }

    /// @notice Subtracts one Fp2 point from another
    /// @param diminished The Fp2 point to be diminished
    /// @param subtracted The Fp2 point to subtract
    /// @return difference The result of the subtraction
    function minusFp2(
        IDkg.Fp2Point memory diminished,
        IDkg.Fp2Point memory subtracted
    )
        internal
        pure
        returns (IDkg.Fp2Point memory difference)
    {
        uint256 p = P;
        if (subtracted.a < diminished.a) {
            difference.a = (p - addmod(subtracted.a, p - diminished.a, p)) % p;
        } else {
            difference.a = addmod(diminished.a, p - subtracted.a, p);
        }
        if (subtracted.b < diminished.b) {
            difference.b = (p - addmod(subtracted.b, p - diminished.b, p)) % p;
        } else {
            difference.b = addmod(diminished.b, p - subtracted.b, p);
        }
    }

    /// @notice Multiplies two Fp2 points
    /// @param value1 The first Fp2 point
    /// @param value2 The second Fp2 point
    /// @return result The product of the two Fp2 points
    function mulFp2(
        IDkg.Fp2Point memory value1,
        IDkg.Fp2Point memory value2
    )
        internal
        pure
        returns (IDkg.Fp2Point memory result)
    {
        uint256 p = P;
        IDkg.Fp2Point memory point = IDkg.Fp2Point({
            a: mulmod(value1.a, value2.a, p),
            b: mulmod(value1.b, value2.b, p)});
        result.a = addmod(
            point.a,
            mulmod(p - 1, point.b, p),
            p);
        result.b = addmod(
            mulmod(
                addmod(value1.a, value1.b, p),
                addmod(value2.a, value2.b, p),
                p),
            p - addmod(point.a, point.b, p),
            p);
    }

    /// @notice Squares an Fp2 point
    /// @param value The Fp2 point to be squared
    /// @return result The square of the input Fp2 point
    function squaredFp2(
        IDkg.Fp2Point memory value
    )
        internal
        pure
        returns (IDkg.Fp2Point memory result)
    {
        uint256 p = P;
        uint256 ab = mulmod(value.a, value.b, p);
        uint256 multiplication = mulmod(
            addmod(value.a, value.b, p),
            addmod(value.a, mulmod(p - 1, value.b, p), p),
            p
        );
        return IDkg.Fp2Point({ a: multiplication, b: addmod(ab, ab, p) });
    }

    /// @notice Checks if two Fp2 points are equal
    /// @param value1 The first Fp2 point
    /// @param value2 The second Fp2 point
    /// @return result True if the two Fp2 points are equal, false otherwise
    function isEqual(
        IDkg.Fp2Point memory value1,
        IDkg.Fp2Point memory value2
    )
        internal
        pure
        returns (bool result)
    {
        return value1.a == value2.a && value1.b == value2.b;
    }
}
