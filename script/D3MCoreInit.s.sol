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

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { MCD, DssInstance } from "dss-test/MCD.sol";
import { ScriptTools } from "dss-test/ScriptTools.sol";

import {
    D3MInit,
    D3MCoreInstance
} from "../src/deploy/D3MInit.sol";

contract D3MCoreInitScript is Script {

    string constant NAME = "core";

    using stdJson for string;
    using ScriptTools for string;

    string config;
    string dependencies;
    DssInstance dss;

    D3MCoreInstance d3mCore;

    function run() external {
        config = ScriptTools.loadConfig(NAME);
        dependencies = ScriptTools.loadDependencies(NAME);
        dss = MCD.loadFromChainlog(config.readAddress("chainlog"));

        d3mCore = D3MCoreInstance({
            hub: dependencies.readAddress("hub"),
            mom: dependencies.readAddress("mom")
        });

        vm.startBroadcast();
        D3MInit.initCore(
            dss,
            d3mCore
        );
        vm.stopBroadcast();
    }

}
