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

/**
 * @title Precompiled
 * @notice Library for interacting with Ethereum precompiled contracts
 */
library Precompiled {

    /// @notice Address of the modular exponentiation precompiled contract
    address public constant MOD_EXP = address(5);

    /// @notice Address of the elliptic curve multiplication precompiled contract
    address public constant EC_MUL = address(7);

    /// @notice Address of the elliptic curve pairing precompiled contract
    address public constant EC_PAIRING = address(8);

    error PrecompiledCallFailed(address precompiledContract);

    /**
     * @notice Performs modular exponentiation using the precompiled contract
     * @dev Calls the MOD_EXP precompiled contract with the given parameters and predefined lengths.
     * @param base The base number
     * @param exponent The exponent
     * @param modulus The modulus
     * @return value The result of (base^exponent) % modulus
     */
    function bigModExp(uint256 base, uint256 exponent, uint256 modulus) internal view returns (uint256 value) {
        uint256 lengthOfBase = 32;
        uint256 lengthOfExponent = 32;
        uint256 lengthOfModulus = 32;

        bytes memory output = _callPrecompiled(
            MOD_EXP, abi.encodePacked(lengthOfBase, lengthOfExponent, lengthOfModulus, base, exponent, modulus)
        );
        return abi.decode(output, (uint256));
    }

    /**
     * @notice Performs scalar multiplication on the elliptic curve using the precompiled contract
     * @dev Calls the EC_MUL precompiled contract with the given parameters.
     * @param x The x-coordinate of the point
     * @param y The y-coordinate of the point
     * @param k The scalar multiplier
     * @return xValue The x-coordinate of the resulting point
     * @return yValue The y-coordinate of the resulting point
     */
    function bn256ScalarMul(uint256 x, uint256 y, uint256 k) internal view returns (uint256 xValue, uint256 yValue) {
        bytes memory output = _callPrecompiled(EC_MUL, abi.encodePacked(x, y, k));
        return abi.decode(output, (uint256, uint256));
    }

    /**
     * @notice Performs pairing check on the elliptic curve using the precompiled contract
     * @dev Calls the EC_PAIRING precompiled contract with the given parameters.
     * @param x1 The x-coordinate of the first G1 point
     * @param y1 The y-coordinate of the first G1 point
     * @param a1 The first coefficient of the first G2 point
     * @param b1 The second coefficient of the first G2 point
     * @param c1 The third coefficient of the first G2 point
     * @param d1 The fourth coefficient of the first G2 point
     * @param x2 The x-coordinate of the second G1 point
     * @param y2 The y-coordinate of the second G1 point
     * @param a2 The first coefficient of the second G2 point
     * @param b2 The second coefficient of the second G2 point
     * @param c2 The third coefficient of the second G2 point
     * @param d2 The fourth coefficient of the second G2 point
     * @return pairing True if the pairing check passes, false otherwise
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
        uint256 d2
    )
        internal
        view
        returns (bool pairing)
    {
        bytes memory output =
            _callPrecompiled(EC_PAIRING, abi.encodePacked(x1, y1, a1, b1, c1, d1, x2, y2, a2, b2, c2, d2));
        return abi.decode(output, (uint256)) != 0;
    }

    /**
     * @notice Retrieves a random 32-byte value from the on-chain RNG
     * @dev Calls the specified RNG precompiled contract (should be SKALE's RNG or compatible) to get a random value.
     * @param rngOnChain The address of the RNG precompiled contract
     * @return addr A random 32-byte value
     */
    function getRandomBytes32(address rngOnChain) internal view returns (bytes32 addr) {
        return bytes32(_callPrecompiled(rngOnChain, ""));
    }

    /**
     * @notice Retrieves a random number from the on-chain RNG
     * @dev Converts the random 32-byte value from getRandomBytes32 to a uint256.
     * @param rngOnChain The address of the RNG precompiled contract
     * @return addr A random uint256 value
     */
    function getRandomNumber(address rngOnChain) internal view returns (uint256 addr) {
        return uint256(getRandomBytes32(rngOnChain));
    }

    // Private

    /**
     * @notice Calls a precompiled contract with the given input
     * @dev Uses low-level staticcall to interact with the precompiled contract.
     * @param precompiledContract The address of the precompiled contract
     * @param input The input data for the call
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
