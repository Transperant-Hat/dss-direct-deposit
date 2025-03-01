// SPDX-FileCopyrightText: © 2022 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.14;

import {DssTest} from "dss-test/DssTest.sol";
import "./interfaces/interfaces.sol";

import {D3MMom} from "../D3MMom.sol";

import {D3MTestPlan} from "./stubs/D3MTestPlan.sol";
interface Hevm {
    function warp(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;

    function load(address, bytes32) external view returns (bytes32);
}

contract D3MMomTest is DssTest {
    D3MTestPlan d3mTestPlan;
    D3MMom d3mMom;

    function setUp() public {
        d3mTestPlan = new D3MTestPlan(address(123));

        d3mTestPlan.file("maxBar_", type(uint256).max);
        d3mTestPlan.file("bar", type(uint256).max);
        d3mMom = new D3MMom();
        d3mTestPlan.rely(address(d3mMom));
    }

    function test_can_disable_plan_owner() public {
        assertEq(d3mTestPlan.bar(), type(uint256).max);

        d3mMom.disable(address(d3mTestPlan));

        assertEq(d3mTestPlan.bar(), 0);
    }

    function test_disable_no_auth() public {
        d3mMom.setOwner(address(0));
        assertEq(d3mMom.authority(), address(0));
        assertEq(d3mMom.owner(), address(0));

        assertRevert(address(d3mMom), abi.encodeWithSignature("disable(address)", address(d3mTestPlan)), "D3MMom/not-authorized");
    }
}
