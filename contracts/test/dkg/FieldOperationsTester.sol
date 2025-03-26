// SPDX-License-Identifier: AGPL-3.0-only

/*
    FieldOperationsTester.sol - playa-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    playa-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    playa-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with playa-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import {IDkg} from "@skalenetwork/playa-manager-interfaces/contracts/IDkg.sol";

import { Fp2Operations } from "../../dkg/fieldOperations/Fp2Operations.sol";
import { G2Operations } from "../../dkg/fieldOperations/G2Operations.sol";


interface IFiedOperationsTester {
    function addG2(IDkg.G2Point calldata value1, IDkg.G2Point calldata value2)
        external
        view
        returns (IDkg.G2Point memory result);
}

contract FieldOperationsTester is IFiedOperationsTester{

    using Fp2Operations for IDkg.Fp2Point;
    using G2Operations for IDkg.G2Point;

    function addG2(IDkg.G2Point calldata value1, IDkg.G2Point calldata value2)
        external
        view
        override
        returns (IDkg.G2Point memory result)
    {
        return value1.addG2(value2);
    }
}
