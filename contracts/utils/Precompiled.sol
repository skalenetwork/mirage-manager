// SPDX-License-Identifier: AGPL-3.0-only

/*
    Precompiled.sol - fair-manager
    Copyright (C) 2018-Present SKALE Labs


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

/**
 * @title Precompiled Library
 * @author Dmytro Stebaiev
 * @author Eduardo Vasques
 * @notice Library for interacting with Ethereum precompiled contracts and SKALE-specific precompiles
 * @dev Provides utilities for modular exponentiation, elliptic curve operations (BN256),
 * and random number generation using SKALE's on-chain RNG.
 */
library Precompiled {

    /// @notice Address of the modular exponentiation precompiled contract
    address public constant MOD_EXP = address(5);

    /// @notice Address of the elliptic curve multiplication precompiled contract (BN256)
    address public constant EC_MUL = address(7);

    /// @notice Address of the elliptic curve pairing precompiled contract (BN256)
    address public constant EC_PAIRING = address(8);

    /// @dev Precompiled contract call failed
    error PrecompiledCallFailed(address precompiledContract);

    /**
     * @notice Performs modular exponentiation: (base^exponent) % modulus
     * @param base The base value
     * @param exponent The exponent value
     * @param modulus The modulus value
     * @return value The result of (base^exponent) % modulus
     */
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

    /**
     * @notice Performs elliptic curve scalar multiplication on BN256 curve
     * @param x The x-coordinate of the point
     * @param y The y-coordinate of the point
     * @param k The scalar multiplier
     * @return xValue The x-coordinate of the resulting point
     * @return yValue The y-coordinate of the resulting point
     */
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

    /**
     * @notice Performs BN256 elliptic curve pairing check
     * @dev Verifies if e(p1[0], p2[0]) * e(p1[1], p2[1]) == 1
     * @param x1 G1 point 1 x-coordinate
     * @param y1 G1 point 1 y-coordinate
     * @param a1 G2 point 1 first component x-coordinate
     * @param b1 G2 point 1 first component y-coordinate
     * @param c1 G2 point 1 second component x-coordinate
     * @param d1 G2 point 1 second component y-coordinate
     * @param x2 G1 point 2 x-coordinate
     * @param y2 G1 point 2 y-coordinate
     * @param a2 G2 point 2 first component x-coordinate
     * @param b2 G2 point 2 first component y-coordinate
     * @param c2 G2 point 2 second component x-coordinate
     * @param d2 G2 point 2 second component y-coordinate
     * @return pairing True if the pairing check passes
     */
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

    /**
     * @notice Gets a random bytes32 value from SKALE's on-chain RNG
     * @dev rngOnChain should be SKALE Random Number Generator predeployed or compatible contract
     * @param rngOnChain The address of the SKALE Random Number Generator predeployed contract
     * @return addr The random bytes32 value
     */
    function getRandomBytes32(address rngOnChain) internal view returns (bytes32 addr) {
        return bytes32(_callPrecompiled(rngOnChain, ""));
    }

    /**
     * @notice Gets a random uint256 value from SKALE's on-chain RNG
     * @param rngOnChain The address of the SKALE Random Number Generator predeployed contract
     * @return addr The random uint256 value
     */
    function getRandomNumber(address rngOnChain) internal view returns (uint256 addr) {
        return uint256(getRandomBytes32(rngOnChain));
    }

    // Private

    /**
     * @notice Calls a precompiled contract with the given input
     * @param precompiledContract The address of the precompiled contract
     * @param input The input data to pass to the precompiled contract
     * @return output The output data from the precompiled contract
     */
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
