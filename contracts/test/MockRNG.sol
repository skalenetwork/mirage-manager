// SPDX-License-Identifier: AGPL-3.0-only

/*
    MockRNG.sol - mirage-manager
    Copyright (C) 2025-Present SKALE Labs
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

contract MockRNG {

    // Just a Mock
    // solhint-disable-next-line comprehensive-interface, no-complex-fallback, payable-fallback
    fallback() external {
        // compute or hard-code your 32-byte value
        bytes32 val = keccak256(abi.encodePacked(block.timestamp));

        // Just a Mock: requires assembly to force return
        // slither-disable-start assembly
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // store it at memory slot 0x00
            mstore(0x00, val)
            // return exactly 32 bytes from memory[0x00..0x20]
            return(0x00, 0x20)
        }
        // slither-disable-end assembly
    }
}
