// SPDX-License-Identifier: AGPL-3.0-only

/*
    Precompiled.sol - mirage-manager
    Copyright (C) 2018-Present SKALE Labs
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


library Precompiled {

    address public constant MOD_EXP = address(5);
    address public constant EC_MUL = address(7);
    address public constant EC_PAIRING = address(8);

    error PrecompiledCallFailed(address precompiledContract);

    function bigModExp(
        uint256 base,
        uint256 exponent,
        uint256 modulus
    )
        internal
        view
        returns (uint256 value)
    {
        uint256 lengthOfBase = 32;
        uint256 lengthOfExponent = 32;
        uint256 lengthOfModulus = 32;

        bytes memory output = _callPrecompiled(MOD_EXP, abi.encodePacked(
            lengthOfBase,
            lengthOfExponent,
            lengthOfModulus,
            base,
            exponent,
            modulus
        ));
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
        bytes memory output = _callPrecompiled(EC_MUL, abi.encodePacked(x, y, k));
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
        bytes memory output = _callPrecompiled(EC_PAIRING, abi.encodePacked(
            x1, y1,
            a1, b1,
            c1, d1,
            x2, y2,
            a2, b2,
            c2, d2
        ));
        return abi.decode(output, (uint256)) != 0;
    }

    // rngOnChain should be SKALE Random Number Generator predeployed or similar
    function getRandomBytes(address rngOnChain) internal view returns (bytes32 addr) {
        return abi.decode(_callPrecompiled(rngOnChain, ""), (bytes32));
    }

    function getRandomNumber(address rngOnChain) internal view returns (uint256 addr) {
        return uint256(getRandomBytes(rngOnChain));
    }

    // Private

    function _callPrecompiled(
        address precompiledContract,
        bytes memory input
    )
        private
        view
        returns (bytes memory output)
    {
        // Have to use low-level calls
        // because it's the only way to call precompiled contracts
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory out) = precompiledContract.staticcall(input);
        require(success, PrecompiledCallFailed(precompiledContract));
        return out;
    }
}
