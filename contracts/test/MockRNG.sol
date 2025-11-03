// SPDX-License-Identifier: AGPL-3.0-only

/*
    MockRNG.sol - fair-manager
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

/**
 * @title IMockRNG
 * @author SKALE Labs
 * @notice Interface for the mock random number generator contract
 * @dev Used for testing purposes to simulate a predeployed RNG contract
 */
interface IMockRNG {
    /**
     * @notice Fallback function that returns mock random data
     * @param input The calldata sent to the contract
     * @return result The encoded mock random data
     */
    fallback(bytes calldata input) external returns (bytes memory result);

    /**
     * @notice Burns all ETH held by the contract by sending it to the zero address
     * @dev Required to satisfy slither security warnings
     */
    function burnEth() external;
}

/**
 * @title MockRNG
 * @author SKALE Labs
 * @notice Mock implementation of a random number generator for testing
 * @dev Simulates a predeployed RNG contract by returning timestamp-based values
 */
contract MockRNG is IMockRNG{

    // If make fallback function payable
    // compiler throws a warning to include a receive function.
    // A receive function can't be defined
    // because it will be called even when no ether is sent
    // and the contract can't mock up the behavior of a predeployed contract
    // because receive function can't return any value.
    // solhint-disable-next-line payable-fallback
    /**
     * @notice Fallback function that returns mock random data based on block timestamp
     * @dev Returns the current block timestamp encoded as bytes
     * @dev Not marked as payable to avoid requiring a receive function, which would interfere with wanted behavior
     * @param input The calldata sent to the contract - ignored
     * @return result The encoded block timestamp as mock random data
     */
    fallback(bytes calldata) external override returns (bytes memory result) {
        return abi.encode(block.timestamp);
    }

    /**
     * @notice Burns all ETH held by the contract by sending it to the zero address
     * @dev Required to satisfy slither security warnings - This contract is used for tests only.
     */
    function burnEth() external override {
        payable(address(0)).transfer(address(this).balance);
    }
}
