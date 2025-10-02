
// SPDX-License-Identifier: AGPL-3.0-only

/*
    RedBlackTreeFuzzy.t.sol - fair-manager
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

// 1. Import Foundry's standard test library
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {RBTHandler, RedBlackTreeTester} from "./handlers/RBTHandler.sol";

// 3. Your test contract must inherit from `Test`

// This is your Handler contract


contract RBTFuzzTest is StdInvariant, Test {
    RedBlackTreeTester public rbt;
    RBTHandler public handler;
    // This function is called before each test case
    function setUp() public {
        rbt = new RedBlackTreeTester();
        handler = new RBTHandler(rbt);
        targetContract(address(handler));
    }

    function invariant_treeIsValid() public view {
        require(rbt.validate(), "TreeIsInvalid");
    }
}