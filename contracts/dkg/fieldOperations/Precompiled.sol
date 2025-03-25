// SPDX-License-Identifier: AGPL-3.0-only

/*
    Precompiled.sol - playa-manager
    Copyright (C) 2018-Present SKALE Labs
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


library Precompiled {

    address public constant MOD_EXP = address(5);
    address public constant EC_MUL = address(7);
    address public constant EC_PAIRING = address(8);

    error BigModExpFailed();
    error MultiplicationFailed();
    error PairingCheckFailed();

    function bigModExp(
        uint256 base,
        uint256 power,
        uint256 modulus
    )
        internal
        view
        returns (uint256 value)
    {
        uint256[6] memory inputToBigModExp;
        inputToBigModExp[0] = 32;
        inputToBigModExp[1] = 32;
        inputToBigModExp[2] = 32;
        inputToBigModExp[3] = base;
        inputToBigModExp[4] = power;
        inputToBigModExp[5] = modulus;
        (bool success, bytes memory output) = MOD_EXP.staticcall(abi.encode(inputToBigModExp));
        require(success, BigModExpFailed());
        return abi.decode(output, (uint256));
    }

    function bn256ScalarMul(
        uint256 x,
        uint256 y,
        uint256 k
    )
        internal
        view
        returns (uint256 xValue, uint256 yValue)
    {
        uint256[3] memory inputToMul;
        inputToMul[0] = x;
        inputToMul[1] = y;
        inputToMul[2] = k;
        (bool success, bytes memory output) = EC_MUL.staticcall(abi.encode(inputToMul));
        require(success, MultiplicationFailed());
        return abi.decode(output, (uint256, uint256));
    }

    function bn256Pairing(
        uint256 x1,
        uint256 y1,
        uint256 a1,
        uint256 b1,
        uint256 c1,
        uint256 d1,
        uint256 x2,
        uint256 y2,
        uint256 a2,
        uint256 b2,
        uint256 c2,
        uint256 d2)
        internal view returns (bool pairing)
    {
        uint256[12] memory inputToPairing;
        inputToPairing[0] = x1;
        inputToPairing[1] = y1;
        inputToPairing[2] = a1;
        inputToPairing[3] = b1;
        inputToPairing[4] = c1;
        inputToPairing[5] = d1;
        inputToPairing[6] = x2;
        inputToPairing[7] = y2;
        inputToPairing[8] = a2;
        inputToPairing[9] = b2;
        inputToPairing[10] = c2;
        inputToPairing[11] = d2;
        (bool success, bytes memory output) = EC_PAIRING.staticcall(abi.encode(inputToPairing));
        require(success, PairingCheckFailed());
        return abi.decode(output, (uint256)) != 0;
    }
}
