// SPDX-License-Identifier: AGPL-3.0-only

/*
    FieldOperationsTester.sol - fair-manager
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

import {IDkg} from "@skalenetwork/fair-manager-interfaces/IDkg.sol";

import { Fp2Operations } from "../../utils/fieldOperations/Fp2Operations.sol";
import { G2Operations } from "../../utils/fieldOperations/G2Operations.sol";

/**
 * @title IFieldOperationsTester
 * @author Dmytro Stebaiev
 * @notice Interface for the FieldOperationsTester contract
 * @dev Provides testing functions for elliptic curve operations on G2
 */
interface IFiedOperationsTester {
    /**
     * @notice Adds two G2 points on the elliptic curve
     * @param value1 The first G2 point
     * @param value2 The second G2 point
     * @return result The sum of the two G2 points
     */
    function addG2(IDkg.G2Point calldata value1, IDkg.G2Point calldata value2)
        external
        view
        returns (IDkg.G2Point memory result);
}

/**
 * @title FieldOperationsTester
 * @author Dmytro Stebaiev
 * @notice Test harness for field and elliptic curve operations
 * @dev Exposes field operations for testing cryptographic primitives used in DKG
 */
contract FieldOperationsTester is IFiedOperationsTester{

    using Fp2Operations for IDkg.Fp2Point;
    using G2Operations for IDkg.G2Point;

    /**
     * @notice Adds two G2 points on the elliptic curve
     * @dev Uses the G2Operations library to perform point addition
     * @param value1 The first G2 point on the BN254 curve
     * @param value2 The second G2 point on the BN254 curve
     * @return result The sum of the two G2 points
     */
    function addG2(IDkg.G2Point calldata value1, IDkg.G2Point calldata value2)
        external
        view
        override
        returns (IDkg.G2Point memory result)
    {
        return value1.addG2(value2);
    }
}
