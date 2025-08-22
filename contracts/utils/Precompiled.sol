// SPDX-License-Identifier: AGPL-3.0-only

/*
    Precompiled.sol - fair-manager
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

/// @title Library for calling precompiled contracts
/// @author Dmytro Stebaiev
/// @notice Provides functions for call precompiled contracts
library Precompiled {

    /// @notice Address of precompiled contract for modular exponentiation
    address public constant MOD_EXP = address(5);
    /// @notice Address of precompiled contract for elliptic curve operations
    address public constant EC_MUL = address(7);
    /// @notice Address of precompiled contract for elliptic curve pairing check
    address public constant EC_PAIRING = address(8);

    error PrecompiledCallFailed(address precompiledContract);

    /// @notice Calculates (base ^ exponent) % modulus
    /// @param base Base number
    /// @param exponent Exponent
    /// @param modulus Modulus
    /// @return value Result of (base ^ exponent) % modulus
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

    /// @notice Performs elliptic curve scalar multiplication
    /// @param x X coordinate of the point
    /// @param y Y coordinate of the point
    /// @param k Scalar to multiply the point by
    /// @return xValue X coordinate of the resulting point
    /// @return yValue Y coordinate of the resulting point
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

    /// @notice Performs elliptic curve pairing check
    /// @param x1 X coordinate of the first point in G1
    /// @param y1 Y coordinate of the first point in G1
    /// @param a1 X real part of the second point in G2
    /// @param b1 X imaginary part of the second point in G2
    /// @param c1 Y real part of the second point in G2
    /// @param d1 Y imaginary part of the second point in G2
    /// @param x2 X coordinate of the third point in G1
    /// @param y2 Y coordinate of the third point in G1
    /// @param a2 X real part of the fourth point in G2
    /// @param b2 X imaginary part of the fourth point in G2
    /// @param c2 Y real part of the fourth point in G2
    /// @param d2 Y imaginary part of the fourth point in G2
    /// @return pairing True if the pairing check passes, false otherwise
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

    /// @notice Gets random bytes32 from on-chain RNG precompiled contract
    /// @dev rngOnChain should be SKALE Random Number Generator predeployed or similar
    /// @param rngOnChain Address of on-chain RNG precompiled contract
    /// @return addr Random bytes32
    function getRandomBytes32(address rngOnChain) internal view returns (bytes32 addr) {
        return bytes32(_callPrecompiled(rngOnChain, ""));
    }

    /// @notice Gets random uint256 from on-chain RNG precompiled contract
    /// @param rngOnChain Address of on-chain RNG precompiled contract
    /// @return addr Random uint256
    function getRandomNumber(address rngOnChain) internal view returns (uint256 addr) {
        return uint256(getRandomBytes32(rngOnChain));
    }

    // Private

    /// @notice Calls precompiled contract with given input
    /// @param precompiledContract Address of precompiled contract
    /// @param input Input data for the precompiled contract
    /// @return output Output data from the precompiled contract
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
