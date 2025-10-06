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

interface IMockRNG {

    fallback(bytes calldata) external returns (bytes memory result);
    function burnEth() external;

}

contract MockRNG is IMockRNG {

    // If make fallback function payable
    // compiler throws a warning to include a receive function.
    // A receive function can't be defined
    // because it will be called even when no ether is sent
    // and the contract can't mock up the behavior of a predeployed contract
    // because receive function can't return any value.
    // solhint-disable-next-line payable-fallback
    fallback(bytes calldata) external override returns (bytes memory result) {
        return abi.encode(block.timestamp);
    }

    // required for slither warning
    function burnEth() external override {
        payable(address(0)).transfer(address(this).balance);
    }

}
