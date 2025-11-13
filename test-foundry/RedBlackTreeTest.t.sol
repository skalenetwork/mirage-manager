// SPDX-License-Identifier: AGPL-3.0-only

// cspell:words: IRBT mixedcase
/*
    RedBlackTreeTest.t.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Eduardo Vasques

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

import {StdInvariant} from "../lib/forge-std/src/StdInvariant.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {RBTHandler, RedBlackTreeTester} from "./handlers/RBTHandler.sol";

/**
 * @title IRBTTest
 * @author Eduardo Vasques
 * @notice Interface for the Red-Black Tree  testing contract
 */
interface IRBTTest {
    /**
     * @notice Thrown when the Red-Black Tree validation fails
     */
    error TreeIsInvalid();

    /**
     * @notice Sets up the testing environment
     */
    function setUp() external;

    // function name follows the naming required by forge invariant testing
    // solhint-disable func-name-mixedcase
    /**
     * @notice Invariant check that validates the Red-Black Tree properties
     * @dev This function is called by Foundry's invariant testing framework
     */
    function invariant_treeIsValid() external view;
    // solhint-enable func-name-mixedcase

    /**
     * @notice Gets the Red-Black Tree tester contract instance
     * @return tester The RedBlackTreeTester contract
     */
    function rbt() external view returns (RedBlackTreeTester tester);

    /**
     * @notice Gets the handler contract instance
     * @return handler The RBTHandler contract
     */
    function handler() external view returns (RBTHandler handler);
}

/**
 * @title RBTTest
 * @author Eduardo Vasques
 * @notice Red-Black Tree testing contract
 */
contract RBTTest is StdInvariant, Test, IRBTTest {

    /// @inheritdoc IRBTTest
    RedBlackTreeTester public rbt;

    /// @inheritdoc IRBTTest
    RBTHandler public handler;

    /// @inheritdoc IRBTTest
    function setUp() public override {
        rbt = new RedBlackTreeTester();
        handler = new RBTHandler(rbt);
        targetContract(address(handler));
    }

    // function name follows the naming required by forge invariant testing
    // solhint-disable func-name-mixedcase

    /// @inheritdoc IRBTTest
    function invariant_treeIsValid() public view override {
        require(rbt.validate(), TreeIsInvalid());
    }
    // solhint-enable func-name-mixedcase
}
