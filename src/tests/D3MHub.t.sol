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

import {D3MHub} from "../D3MHub.sol";
import {D3MOracle} from "../D3MOracle.sol";
import "../pools/ID3MPool.sol";
import "../plans/ID3MPlan.sol";

import {D3MTestPool} from "./stubs/D3MTestPool.sol";
import {D3MTestPlan} from "./stubs/D3MTestPlan.sol";
import {D3MTestGem} from "./stubs/D3MTestGem.sol";
import {D3MTestRewards} from "./stubs/D3MTestRewards.sol";

interface Hevm {
    function warp(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;

    function load(address, bytes32) external view returns (bytes32);
}

contract D3MHubTest is DssTest {
    VatLike vat;
    EndLike end;
    D3MTestRewards rewardsClaimer;
    DaiLike dai;
    DaiJoinLike daiJoin;
    D3MTestGem testGem;
    TokenLike testReward;
    SpotLike spot;
    TokenLike weth;
    address vow;
    address pauseProxy;

    bytes32 constant ilk = "DD-DAI-TEST";
    D3MHub d3mHub;
    D3MTestPool d3mTestPool;
    D3MTestPlan d3mTestPlan;
    D3MOracle pip;

    function setUp() public {
        vat = VatLike(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
        end = EndLike(0x0e2e8F1D1326A4B9633D96222Ce399c708B19c28);
        dai = DaiLike(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        daiJoin = DaiJoinLike(0x9759A6Ac90977b93B58547b4A71c78317f391A28);
        spot = SpotLike(0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3);
        weth = TokenLike(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        vow = 0xA950524441892A31ebddF91d3cEEFa04Bf454466;
        pauseProxy = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

        // Force give admin access to these contracts via vm magic
        _giveAuthAccess(address(vat), address(this));
        _giveAuthAccess(address(end), address(this));
        _giveAuthAccess(address(spot), address(this));

        testGem = new D3MTestGem(18);
        d3mHub = new D3MHub(address(daiJoin));

        rewardsClaimer = new D3MTestRewards(address(testGem));
        d3mTestPool = new D3MTestPool(
            address(d3mHub),
            address(dai),
            address(testGem),
            address(rewardsClaimer)
        );
        d3mTestPool.rely(address(d3mHub));
        d3mTestPlan = new D3MTestPlan(address(dai));

        // Test Target Setup
        testGem.rely(address(d3mTestPool));
        d3mTestPlan.file("maxBar_", type(uint256).max);
        testGem.giveAllowance(
            address(dai),
            address(d3mTestPool),
            type(uint256).max
        );

        d3mHub.file("vow", vow);
        d3mHub.file("end", address(end));

        d3mHub.file(ilk, "pool", address(d3mTestPool));
        d3mHub.file(ilk, "plan", address(d3mTestPlan));
        d3mHub.file(ilk, "tau", 7 days);

        // Init new collateral
        pip = new D3MOracle(address(vat), ilk);
        pip.file("hub", address(d3mHub));
        spot.file(ilk, "pip", address(pip));
        spot.file(ilk, "mat", RAY);
        spot.poke(ilk);

        vat.rely(address(d3mHub));
        vat.init(ilk);
        vat.file(ilk, "line", 5_000_000_000 * RAD);
        vat.file("Line", vat.Line() + 5_000_000_000 * RAD);
    }

    // --- Math ---
    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }

    function _giveAuthAccess(address _base, address target) internal {
        AuthLike base = AuthLike(_base);

        // Edge case - ward is already set
        if (base.wards(target) == 1) return;

        for (int256 i = 0; i < 100; i++) {
            // Scan the storage for the ward storage slot
            bytes32 prevValue = vm.load(
                address(base),
                keccak256(abi.encode(target, uint256(i)))
            );
            vm.store(
                address(base),
                keccak256(abi.encode(target, uint256(i))),
                bytes32(uint256(1))
            );
            if (base.wards(target) == 1) {
                // Found it
                return;
            } else {
                // Keep going after restoring the original value
                vm.store(
                    address(base),
                    keccak256(abi.encode(target, uint256(i))),
                    prevValue
                );
            }
        }

        // We have failed if we reach here
        assertTrue(false);
    }

    function _giveTokens(TokenLike token, uint256 amount) internal {
        _giveTokens(token, address(this), amount);
    }

    function _giveTokens(
        TokenLike token,
        address usr,
        uint256 amount
    ) internal {
        // Edge case - balance is already set for some reason
        if (token.balanceOf(address(usr)) == amount) return;

        for (int256 i = 0; i < 100; i++) {
            // Scan the storage for the balance storage slot
            bytes32 prevValue = vm.load(
                address(token),
                keccak256(abi.encode(address(usr), uint256(i)))
            );
            vm.store(
                address(token),
                keccak256(abi.encode(address(usr), uint256(i))),
                bytes32(amount)
            );
            if (token.balanceOf(address(usr)) == amount) {
                // Found it
                return;
            } else {
                // Keep going after restoring the original value
                vm.store(
                    address(token),
                    keccak256(abi.encode(address(usr), uint256(i))),
                    prevValue
                );
            }
        }

        // We have failed if we reach here
        assertTrue(false);
    }

    function _windSystem() internal {
        d3mTestPlan.file("bar", 10);
        d3mTestPlan.file("targetAssets", 50 * WAD);
        d3mHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
        d3mTestPool.file("preDebt", false); // reset preDebt
        d3mTestPool.file("postDebt", false); // reset postDebt
    }

    function test_approvals() public {
        assertEq(
            dai.allowance(address(d3mHub), address(daiJoin)),
            type(uint256).max
        );
        assertEq(vat.can(address(d3mHub), address(daiJoin)), 1);
    }

    function test_can_file_tau() public {
        (, , uint256 tau, , ) = d3mHub.ilks(ilk);
        assertEq(tau, 7 days);
        d3mHub.file(ilk, "tau", 1 days);
        (, , tau, , ) = d3mHub.ilks(ilk);
        assertEq(tau, 1 days);
    }

    function test_unauth_file_tau() public {
        d3mHub.deny(address(this));
        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ilk, bytes32("tau"), uint256(1 days)), "D3MHub/not-authorized");
    }

    function test_unknown_uint256_file() public {
        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,uint256)", ilk, bytes32("unknown"), uint256(1)), "D3MHub/file-unrecognized-param");
    }

    function test_unknown_address_file() public {
        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,address)", ilk, bytes32("unknown"), address(this)), "D3MHub/file-unrecognized-param");
    }

    function test_can_file_pool() public {
        (ID3MPool pool, , , , ) = d3mHub.ilks(ilk);

        assertEq(address(pool), address(d3mTestPool));

        d3mHub.file(ilk, "pool", address(this));

        (pool, , , , ) = d3mHub.ilks(ilk);
        assertEq(address(pool), address(this));
    }

    function test_can_file_plan() public {
        (, ID3MPlan plan, , , ) = d3mHub.ilks(ilk);

        assertEq(address(plan), address(d3mTestPlan));

        d3mHub.file(ilk, "plan", address(this));

        (, plan, , , ) = d3mHub.ilks(ilk);
        assertEq(address(plan), address(this));
    }

    function test_can_file_vow() public {
        address setVow = d3mHub.vow();

        assertEq(vow, setVow);

        d3mHub.file("vow", address(this));

        setVow = d3mHub.vow();
        assertEq(setVow, address(this));
    }

    function test_can_file_end() public {
        address setEnd = address(d3mHub.end());

        assertEq(address(end), setEnd);

        d3mHub.file("end", address(this));

        setEnd = address(d3mHub.end());
        assertEq(setEnd, address(this));
    }

    function test_vat_not_live_address_file() public {
        d3mHub.file("end", address(this));
        address hubEnd = address(d3mHub.end());

        assertEq(hubEnd, address(this));

        // MCD shutdowns
        end.cage();
        end.cage(ilk);

        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,address)", bytes32("end"), address(123)), "D3MHub/no-file-during-shutdown");
    }

    function test_unauth_file_pool() public {
        d3mHub.deny(address(this));
        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,address)", ilk, bytes32("pool"), address(this)), "D3MHub/not-authorized");
    }

    function test_hub_not_live_pool_file() public {
        // Cage Pool
        d3mHub.cage(ilk);
        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,address)", ilk, bytes32("pool"), address(123)), "D3MHub/pool-not-live");
    }

    function test_unknown_ilk_address_file() public {
        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,address)", ilk, bytes32("unknown"), address(123)), "D3MHub/file-unrecognized-param");
    }

    function test_vat_not_live_ilk_address_file() public {
        d3mHub.file(ilk, "pool", address(this));
        (ID3MPool pool, , , , ) = d3mHub.ilks(ilk);

        assertEq(address(pool), address(this));

        // MCD shutdowns
        end.cage();
        end.cage(ilk);

        assertRevert(address(d3mHub), abi.encodeWithSignature("file(bytes32,bytes32,address)", ilk, bytes32("pool"), address(123)), "D3MHub/no-file-during-shutdown");
    }

    function test_exec_no_ilk() public {
        assertRevert(address(d3mHub), abi.encodeWithSignature("exec(bytes32)", bytes32("fake-ilk")), "D3MHub/rate-not-one");
    }

    function test_exec_rate_not_one() public {
        vat.fold(ilk, vow, int(2 * RAY));
        assertRevert(address(d3mHub), abi.encodeWithSignature("exec(bytes32)", ilk), "D3MHub/rate-not-one");
    }

    function test_exec_spot_not_one() public {
        vat.file(ilk, "spot", 2 * RAY);
        assertRevert(address(d3mHub), abi.encodeWithSignature("exec(bytes32)", ilk), "D3MHub/spot-not-one");
    }

    function test_wind_limited_ilk_line() public {
        d3mTestPlan.file("bar", 10);
        d3mTestPlan.file("targetAssets", 50 * WAD);
        vat.file(ilk, "line", 40 * RAD);
        d3mHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 40 * WAD);
        assertEq(art, 40 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_wind_limited_Line() public {
        d3mTestPlan.file("bar", 10);
        d3mTestPlan.file("targetAssets", 50 * WAD);
        vat.file("Line", vat.debt() + 40 * RAD);
        d3mHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 40 * WAD);
        assertEq(art, 40 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_wind_limited_by_maxDeposit() public {
        _windSystem(); // winds to 50 * WAD
        d3mTestPlan.file("targetAssets", 75 * WAD);
        d3mTestPool.file("maxDepositAmount", 5 * WAD);

        d3mHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 55 * WAD);
        assertEq(art, 55 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_wind_limited_to_zero_by_maxDeposit() public {
        _windSystem(); // winds to 50 * WAD
        d3mTestPlan.file("targetAssets", 75 * WAD);
        d3mTestPool.file("maxDepositAmount", 0);

        d3mHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_fixes_after_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 viceBefore = vat.vice();
        uint256 sinBefore = vat.sin(vow);
        uint256 vowDaiBefore = vat.dai(vow);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);

        // It will just fix the position and send the DAI to the surplus buffer
        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        assertEq(vat.dai(vow), vowDaiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);

        // can reduce and have the correct amount of locked collateral
        d3mTestPlan.file("targetAssets", 25 * WAD);

        // exec and unwind
        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 25 * WAD);
        assertEq(art, 25 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        assertEq(vat.dai(vow), vowDaiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 25 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 25 * WAD);
    }

    function test_wind_after_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 viceBefore = vat.vice();
        uint256 sinBefore = vat.sin(vow);
        uint256 vowDaiBefore = vat.dai(vow);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);

        // can re-wind and have the correct amount of debt (art)
        d3mTestPlan.file("targetAssets", 75 * WAD);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 75 * WAD);
        assertEq(art, 75 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        assertEq(vat.dai(vow), vowDaiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 75 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 75 * WAD);
    }

    function test_fully_unwind_after_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 viceBefore = vat.vice();
        uint256 sinBefore = vat.sin(vow);
        uint256 vowDaiBefore = vat.dai(vow);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);

        // fully unwind
        d3mTestPlan.file("targetAssets", 0);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0 * WAD);
        assertEq(art, 0 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        // This comes back to us as fees at this point
        assertEq(vat.dai(vow), vowDaiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 0 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 0 * WAD);
    }

    function test_wind_unwind_line_limited_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        (uint256 Art, , , , ) = vat.ilks(ilk);
        assertEq(Art, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 viceBefore = vat.vice();
        uint256 sinBefore = vat.sin(vow);
        uint256 vowDaiBefore = vat.dai(vow);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);

        // limit wind with debt ceiling
        d3mTestPlan.file("targetAssets", 500 * WAD);
        vat.file(ilk, "line", 60 * RAD);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 60 * WAD);
        assertEq(art, 60 * WAD);
        (Art, , , , ) = vat.ilks(ilk);
        assertEq(Art, 60 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        assertEq(vat.dai(vow), vowDaiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 60 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);

        // unwind due to debt ceiling
        vat.file(ilk, "line", 20 * RAD);

        // we can now execute the unwind to respect the line again
        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 20 * WAD);
        assertEq(art, 20 * WAD);
        (Art, , , , ) = vat.ilks(ilk);
        assertEq(Art, 20 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        // we unwind and collect fees
        assertEq(vat.dai(vow), vowDaiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 20 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 20 * WAD);
    }

    function test_exec_fees_debt_paid_back() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 5 * WAD);
        testGem.transfer(address(d3mTestPool), 5 * WAD);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 55 * WAD);

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        (uint256 Art, , , , ) = vat.ilks(ilk);
        assertEq(Art, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 viceBefore = vat.vice();
        uint256 sinBefore = vat.sin(vow);
        uint256 vowDaiBefore = vat.dai(vow);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 55 * WAD);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        (Art, , , , ) = vat.ilks(ilk);
        assertEq(Art, 50 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.dai(address(d3mHub)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        // Both the debt donation and fees go to vow
        assertEq(vat.dai(vow), vowDaiBefore + 15 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 45 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);
    }

    function test_unwind_plan_not_active() public {
        _windSystem();

        // Temporarily disable the module
        d3mTestPlan.file("active_", false);
        d3mHub.exec(ilk);

        // Ensure we unwound our position
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_bar_zero() public {
        _windSystem();

        // Temporarily disable the module
        d3mTestPlan.file("bar", 0);
        d3mHub.exec(ilk);

        // Ensure we unwound our position
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_ilk_line_lowered() public {
        _windSystem();

        // Set ilk line below current debt
        d3mTestPlan.file("targetAssets", 55 * WAD); // Increasing target in 5 WAD
        vat.file(ilk, "line", 45 * RAD);
        d3mHub.exec(ilk);

        // Ensure we unwound our position to debt ceiling
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 45 * WAD); // Instead of 5 WAD more results in 5 WAD less due debt ceiling
        assertEq(art, 45 * WAD);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_global_Line_lowered() public {
        _windSystem();

        // Set ilk line below current debt
        d3mTestPlan.file("targetAssets", 55 * WAD); // Increasing target in 5 WAD
        vat.file("Line", vat.debt() - 5 * RAD);
        d3mHub.exec(ilk);

        // Ensure we unwound our position to debt ceiling
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 45 * WAD); // Instead of 5 WAD more results in 5 WAD less due debt ceiling
        assertEq(art, 45 * WAD);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_mcd_caged() public {
        _windSystem();

        // MCD shuts down
        end.cage();
        end.cage(ilk);

        d3mHub.exec(ilk);

        // Ensure we unwound our position
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_mcd_caged_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        // MCD shuts down
        end.cage();
        end.cage(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        assertEq(vat.gem(ilk, address(end)), 0);
        uint256 sinBefore = vat.sin(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 10 * WAD);
        assertEq(art, 0);
        assertEq(vat.gem(ilk, address(end)), 0);
        assertEq(vat.dai(address(d3mHub)), 0);
        assertEq(vat.sin(vow), sinBefore + 40 * RAD);
    }

    function test_unwind_pool_caged() public {
        _windSystem();

        // Module caged
        d3mHub.cage(ilk);

        d3mHub.exec(ilk);

        // Ensure we unwound our position
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_unwind_pool_caged_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        // Module caged
        d3mHub.cage(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);
        uint256 viceBefore = vat.vice();
        uint256 sinBefore = vat.sin(vow);
        uint256 daiBefore = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.dai(address(d3mHub)), 0);
        assertEq(vat.vice(), viceBefore);
        assertEq(vat.sin(vow), sinBefore);
        assertEq(vat.dai(vow), daiBefore + 10 * RAD);
        assertEq(dai.balanceOf(address(testGem)), 0);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 0);
    }

    function test_unwind_target_less_amount() public {
        _windSystem();

        (uint256 pink, uint256 part) = vat.urns(ilk, address(d3mTestPool));
        assertEq(pink, 50 * WAD);
        assertEq(part, 50 * WAD);

        d3mTestPlan.file("targetAssets", 25 * WAD);

        d3mHub.exec(ilk);

        // Ensure we unwound our position
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 25 * WAD);
        assertEq(art, 25 * WAD);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_wind_unwind_non_standard_token() public {
        // setup system
        bytes32 otherIlk = "DD-OTHER-GEM";
        D3MTestGem otherGem = new D3MTestGem(6);
        D3MTestRewards otherRewards = new D3MTestRewards(address(otherGem));
        D3MTestPool otherPool = new D3MTestPool(
            address(d3mHub),
            address(dai),
            address(otherGem),
            address(otherRewards)
        );
        otherPool.rely(address(d3mHub));
        otherGem.rely(address(otherPool));
        otherGem.giveAllowance(
            address(dai),
            address(otherPool),
            type(uint256).max
        );

        d3mHub.file(otherIlk, "pool", address(otherPool));
        d3mHub.file(otherIlk, "plan", address(d3mTestPlan));
        d3mHub.file(otherIlk, "tau", 7 days);

        spot.file(otherIlk, "pip", address(pip));
        spot.file(otherIlk, "mat", RAY);
        spot.poke(otherIlk);
        vat.init(otherIlk);
        vat.file(otherIlk, "line", 5_000_000_000 * RAD);
        vat.file("Line", vat.Line() + 10_000_000_000 * RAD);

        // wind up system
        d3mTestPlan.file("bar", 10);
        d3mTestPlan.file("targetAssets", 50 * WAD);
        d3mHub.exec(otherIlk);

        (uint256 ink, uint256 art) = vat.urns(otherIlk, address(otherPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertTrue(otherPool.preDebt());
        assertTrue(otherPool.postDebt());
        otherPool.file("preDebt", false); // reset preDebt
        otherPool.file("postDebt", false); // reset postDebt

        // wind down system
        d3mTestPlan.file("bar", 10);
        d3mTestPlan.file("targetAssets", 5 * WAD);
        d3mHub.exec(otherIlk);

        (ink, art) = vat.urns(otherIlk, address(otherPool));
        assertEq(ink, 5 * WAD);
        assertEq(art, 5 * WAD);
        assertTrue(otherPool.preDebt());
        assertTrue(otherPool.postDebt());
        otherPool.file("preDebt", false); // reset preDebt
        otherPool.file("postDebt", false); // reset postDebt
    }

    function test_exec_fees_available_liquidity() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD);

        (, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(art, 50 * WAD);
        uint256 currentDai = vat.dai(vow);
        assertEq(currentDai, prevDai + 10 * RAD); // Interest shows up in vat Dai for the Vow [rad]
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_exec_fees_not_enough_liquidity() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        // If we do not have enough liquidity then we pull out what we can for the fees
        // This will pull out all but 2 WAD of the liquidity
        assertEq(dai.balanceOf(address(testGem)), 50 * WAD); // liquidity before simulating other user's withdraw
        testGem.giveAllowance(address(dai), address(this), type(uint256).max);
        dai.transferFrom(address(testGem), address(this), 48 * WAD);
        assertEq(dai.balanceOf(address(testGem)), 2 * WAD); // liquidity after

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        // Collateral and debt increase by 8 WAD as there wasn't enough liquidity to pay the fees accumulated
        assertEq(ink, 58 * WAD);
        assertEq(art, 58 * WAD);
         // 10 RAY immediately shows up in the surplus
        assertEq(vat.dai(vow), prevDai + 10 * RAD);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_exit() public {
        _windSystem();
        // Vat is caged for global settlement
        vat.cage();

        // Simulate DAI holder gets some gems from GS
        vat.grab(
            ilk,
            address(d3mTestPool),
            address(this),
            address(this),
            -int256(50 * WAD),
            -int256(0)
        );

        uint256 prevBalance = testGem.balanceOf(address(this));

        // User can exit and get the aDAI
        d3mHub.exit(ilk, address(this), 50 * WAD);
        assertEq(testGem.balanceOf(address(this)), prevBalance + 50 * WAD);
    }

    function test_cage_d3m_with_auth() public {
        (, , uint256 tau, , uint256 tic) = d3mHub.ilks(ilk);
        assertEq(tic, 0);

        d3mHub.cage(ilk);

        (, , , , tic) = d3mHub.ilks(ilk);
        assertEq(tic, block.timestamp + tau);
    }

    function test_cage_d3m_mcd_caged() public {
        vat.cage();
        assertRevert(address(d3mHub), abi.encodeWithSignature("cage(bytes32)", ilk), "D3MHub/no-cage-during-shutdown");
    }

    function test_cage_d3m_no_auth() public {
        d3mHub.deny(address(this));
        assertRevert(address(d3mHub), abi.encodeWithSignature("cage(bytes32)", ilk), "D3MHub/not-authorized");
    }

    function test_cage_d3m_already_caged() public {
        d3mHub.cage(ilk);
        assertRevert(address(d3mHub), abi.encodeWithSignature("cage(bytes32)", ilk), "D3MHub/pool-already-caged");
    }

    function test_cull() public {
        _windSystem();
        d3mHub.cage(ilk);

        (uint256 pink, uint256 part) = vat.urns(ilk, address(d3mTestPool));
        assertEq(pink, 50 * WAD);
        assertEq(part, 50 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 sinBefore = vat.sin(vow);

        d3mHub.cull(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 50 * WAD);
        assertEq(vat.sin(vow), sinBefore + 50 * RAD);
        (, , , uint256 culled, ) = d3mHub.ilks(ilk);
        assertEq(culled, 1);
    }

    function test_cull_debt_paid_back() public {
        _windSystem();

        // Someone pays back our debt
        _giveTokens(dai, 10 * WAD);
        dai.approve(address(daiJoin), type(uint256).max);
        daiJoin.join(address(this), 10 * WAD);
        vat.frob(
            ilk,
            address(d3mTestPool),
            address(d3mTestPool),
            address(this),
            0,
            -int256(10 * WAD)
        );

        d3mHub.cage(ilk);

        (uint256 pink, uint256 part) = vat.urns(ilk, address(d3mTestPool));
        assertEq(pink, 50 * WAD);
        assertEq(part, 40 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 sinBefore = vat.sin(vow);
        uint256 vowDaiBefore = vat.dai(vow);

        d3mHub.cull(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 50 * WAD);
        assertEq(vat.dai(address(d3mHub)), 0);
        // Sin only increases by 40 WAD since 10 was covered previously
        assertEq(vat.sin(vow), sinBefore + 40 * RAD);
        assertEq(vat.dai(vow), vowDaiBefore);
        (, , , uint256 culled, ) = d3mHub.ilks(ilk);
        assertEq(culled, 1);

        d3mHub.exec(ilk);

        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        assertEq(vat.dai(address(d3mHub)), 0);
        // Still 50 WAD because the extra 10 WAD from repayment are not
        // accounted for in the fees from unwind
        assertEq(vat.dai(vow), vowDaiBefore + 50 * RAD);
    }

    function test_cull_no_auth_time_passed() public {
        _windSystem();
        d3mHub.cage(ilk);
        // with auth we can cull anytime
        d3mHub.deny(address(this));
        // but with enough time, anyone can cull
        vm.warp(block.timestamp + 7 days);

        (uint256 pink, uint256 part) = vat.urns(ilk, address(d3mTestPool));
        assertEq(pink, 50 * WAD);
        assertEq(part, 50 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        uint256 sinBefore = vat.sin(vow);

        d3mHub.cull(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 0);
        assertEq(art, 0);
        uint256 gemAfter = vat.gem(ilk, address(d3mTestPool));
        assertEq(gemAfter, 50 * WAD);
        assertEq(vat.sin(vow), sinBefore + 50 * RAD);
        (, , , uint256 culled, ) = d3mHub.ilks(ilk);
        assertEq(culled, 1);
    }

    function test_no_cull_mcd_caged() public {
        _windSystem();
        d3mHub.cage(ilk);
        vat.cage();

        assertRevert(address(d3mHub), abi.encodeWithSignature("cull(bytes32)", ilk), "D3MHub/no-cull-during-shutdown");
    }

    function test_no_cull_pool_live() public {
        _windSystem();

        assertRevert(address(d3mHub), abi.encodeWithSignature("cull(bytes32)", ilk), "D3MHub/pool-live");
    }

    function test_no_cull_unauth_too_soon() public {
        _windSystem();
        d3mHub.cage(ilk);
        d3mHub.deny(address(this));
        vm.warp(block.timestamp + 6 days);

        assertRevert(address(d3mHub), abi.encodeWithSignature("cull(bytes32)", ilk), "D3MHub/unauthorized-cull");
    }

    function test_no_cull_already_culled() public {
        _windSystem();
        d3mHub.cage(ilk);

        d3mHub.cull(ilk);
        assertRevert(address(d3mHub), abi.encodeWithSignature("cull(bytes32)", ilk), "D3MHub/already-culled");
    }

    function test_no_cull_no_ilk() public {
        assertRevert(address(d3mHub), abi.encodeWithSignature("cull(bytes32)", bytes32("fake-ilk")), "D3MHub/pool-live");
    }

    function test_uncull() public {
        _windSystem();
        d3mHub.cage(ilk);

        d3mHub.cull(ilk);
        (uint256 pink, uint256 part) = vat.urns(ilk, address(d3mTestPool));
        assertEq(pink, 0);
        assertEq(part, 0);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 50 * WAD);
        uint256 sinBefore = vat.sin(vow);
        (, , , uint256 culled, ) = d3mHub.ilks(ilk);
        assertEq(culled, 1);

        vat.cage();
        d3mHub.uncull(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.gem(ilk, address(d3mTestPool)), 0);
        // Sin should not change since we suck before grabbing
        assertEq(vat.sin(vow), sinBefore);
        (, , , culled, ) = d3mHub.ilks(ilk);
        assertEq(culled, 0);
    }

    function test_no_uncull_not_culled() public {
        _windSystem();
        d3mHub.cage(ilk);

        vat.cage();
        assertRevert(address(d3mHub), abi.encodeWithSignature("uncull(bytes32)", ilk), "D3MHub/not-prev-culled");
    }

    function test_no_uncull_mcd_live() public {
        _windSystem();
        d3mHub.cage(ilk);

        d3mHub.cull(ilk);

        assertRevert(address(d3mHub), abi.encodeWithSignature("uncull(bytes32)", ilk), "D3MHub/no-uncull-normal-operation");
    }

    function test_quit_culled() public {
        _windSystem();
        d3mHub.cage(ilk);

        d3mHub.cull(ilk);

        address receiver = address(123);

        uint256 balBefore = testGem.balanceOf(receiver);
        assertEq(50 * WAD, testGem.balanceOf(address(d3mTestPool)));
        assertEq(50 * WAD, vat.gem(ilk, address(d3mTestPool)));

        d3mTestPool.quit(receiver);
        vat.slip(
            ilk,
            address(d3mTestPool),
            -int256(vat.gem(ilk, address(d3mTestPool)))
        );

        assertEq(testGem.balanceOf(receiver), balBefore + 50 * WAD);
        assertEq(0, testGem.balanceOf(address(d3mTestPool)));
        assertEq(0, vat.gem(ilk, address(d3mTestPool)));
    }

    function test_quit_not_culled() public {
        _windSystem();

        address receiver = address(123);
        uint256 balBefore = testGem.balanceOf(receiver);
        assertEq(50 * WAD, testGem.balanceOf(address(d3mTestPool)));
        (uint256 pink, uint256 part) = vat.urns(ilk, address(d3mTestPool));
        assertEq(pink, 50 * WAD);
        assertEq(part, 50 * WAD);
        (uint256 tink, uint256 tart) = vat.urns(ilk, receiver);
        assertEq(tink, 0);
        assertEq(tart, 0);

        d3mTestPool.quit(receiver);
        vat.grab(
            ilk,
            address(d3mTestPool),
            receiver,
            receiver,
            -int256(pink),
            -int256(part)
        );
        vat.grab(ilk, receiver, receiver, receiver, int256(pink), int256(part));

        assertEq(testGem.balanceOf(receiver), balBefore + 50 * WAD);
        (uint256 joinInk, uint256 joinArt) = vat.urns(
            ilk,
            address(d3mTestPool)
        );
        assertEq(joinInk, 0);
        assertEq(joinArt, 0);
        (uint256 ink, uint256 art) = vat.urns(ilk, receiver);
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
    }

    function test_pool_upgrade_unwind_wind() public {
        _windSystem(); // Tests that the current pool has ink/art

        // Setup new pool
        D3MTestPool newPool = new D3MTestPool(
            address(d3mHub),
            address(dai),
            address(testGem),
            address(rewardsClaimer)
        );
        newPool.rely(address(d3mHub));
        testGem.rely(address(newPool));
        testGem.giveAllowance(
            address(dai),
            address(newPool),
            type(uint256).max
        );

        (uint256 npink, uint256 npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 0);
        assertEq(npart, 0);
        assertTrue(newPool.preDebt() == false);
        assertTrue(newPool.postDebt() == false);

        // Plan Inactive
        d3mTestPlan.file("active_", false);
        assertTrue(d3mTestPlan.active() == false);

        d3mHub.exec(ilk);

        // Ensure we unwound our position
        (uint256 opink, uint256 opart) = vat.urns(ilk, address(d3mTestPool));
        assertEq(opink, 0);
        assertEq(opart, 0);
        // Make sure pre/post functions get called
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
        d3mTestPool.file("preDebt", false); // reset preDebt
        d3mTestPool.file("postDebt", false); // reset postDebt

        d3mHub.file(ilk, "pool", address(newPool));
        // Reactivate Plan
        d3mTestPlan.file("active_", true);
        assertTrue(d3mTestPlan.active());
        d3mHub.exec(ilk);

        // New Pool should get wound up to the original amount because plan didn't change
        (npink, npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 50 * WAD);
        assertEq(npart, 50 * WAD);
        assertTrue(newPool.preDebt());
        assertTrue(newPool.postDebt());

        (opink, opart) = vat.urns(ilk, address(d3mTestPool));
        assertEq(opink, 0);
        assertEq(opart, 0);
        // Make sure unwind calls hooks
        assertTrue(d3mTestPool.preDebt() == false);
        assertTrue(d3mTestPool.postDebt() == false);
    }

    function test_pool_upgrade_quit() public {
        _windSystem(); // Tests that the current pool has ink/art

        // Setup new pool
        D3MTestPool newPool = new D3MTestPool(
            address(d3mHub),
            address(dai),
            address(testGem),
            address(rewardsClaimer)
        );
        newPool.rely(address(d3mHub));
        testGem.rely(address(newPool));
        testGem.giveAllowance(
            address(dai),
            address(newPool),
            type(uint256).max
        );

        (uint256 opink, uint256 opart) = vat.urns(ilk, address(d3mTestPool));
        assertGt(opink, 0);
        assertGt(opart, 0);

        (uint256 npink, uint256 npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 0);
        assertEq(npart, 0);
        assertTrue(newPool.preDebt() == false);
        assertTrue(newPool.postDebt() == false);

        // quit to new pool
        d3mTestPool.quit(address(newPool));
        vat.grab(
            ilk,
            address(d3mTestPool),
            address(newPool),
            address(newPool),
            -int256(opink),
            -int256(opart)
        );
        vat.grab(
            ilk,
            address(newPool),
            address(newPool),
            address(newPool),
            int256(opink),
            int256(opart)
        );

        // Ensure we quit our position
        (opink, opart) = vat.urns(ilk, address(d3mTestPool));
        assertEq(opink, 0);
        assertEq(opart, 0);
        // quit does not call hooks
        assertTrue(d3mTestPool.preDebt() == false);
        assertTrue(d3mTestPool.postDebt() == false);

        (npink, npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 50 * WAD);
        assertEq(npart, 50 * WAD);
        assertTrue(newPool.preDebt() == false);
        assertTrue(newPool.postDebt() == false);

        // file new pool
        d3mHub.file(ilk, "pool", address(newPool));

        // test unwind/wind
        d3mTestPlan.file("targetAssets", 45 * WAD);
        d3mHub.exec(ilk);

        (opink, opart) = vat.urns(ilk, address(d3mTestPool));
        assertEq(opink, 0);
        assertEq(opart, 0);

        (npink, npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 45 * WAD);
        assertEq(npart, 45 * WAD);

        d3mTestPlan.file("targetAssets", 100 * WAD);
        d3mHub.exec(ilk);

        (opink, opart) = vat.urns(ilk, address(d3mTestPool));
        assertEq(opink, 0);
        assertEq(opart, 0);

        (npink, npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 100 * WAD);
        assertEq(npart, 100 * WAD);
    }

    function test_plan_upgrade() public {
        _windSystem(); // Tests that the current pool has ink/art

        // Setup new plan
        D3MTestPlan newPlan = new D3MTestPlan(address(dai));
        newPlan.file("maxBar_", type(uint256).max);
        newPlan.file("bar", 5);
        newPlan.file("targetAssets", 100 * WAD);

        d3mHub.file(ilk, "plan", address(newPlan));

        (, ID3MPlan plan, , , ) = d3mHub.ilks(ilk);
        assertEq(address(plan), address(newPlan));

        d3mHub.exec(ilk);

        // New Plan should determine the pool position
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 100 * WAD);
        assertEq(art, 100 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function test_hub_upgrade_same_d3ms() public {
        _windSystem(); // Tests that the current pool has ink/art

        // Setup New hub
        D3MHub newHub = new D3MHub(address(daiJoin));
        newHub.file("vow", vow);
        newHub.file("end", address(end));

        newHub.file(ilk, "pool", address(d3mTestPool));
        newHub.file(ilk, "plan", address(d3mTestPlan));
        newHub.file(ilk, "tau", 7 days);

        // Update permissions on d3ms
        d3mTestPool.rely(address(newHub));
        d3mTestPool.deny(address(d3mHub));
        d3mTestPool.file("hub", address(newHub));

        // Update Permissions in Vat
        vat.deny(address(d3mHub));
        vat.rely(address(newHub));

        // Clean up old hub
        d3mHub.file(ilk, "pool", address(0));
        d3mHub.file(ilk, "plan", address(0));
        d3mHub.file(ilk, "tau", 0);

        // Ensure new hub operation
        d3mTestPlan.file("bar", 10);
        d3mTestPlan.file("targetAssets", 100 * WAD);
        newHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 100 * WAD);
        assertEq(art, 100 * WAD);
        assertTrue(d3mTestPool.preDebt());
        assertTrue(d3mTestPool.postDebt());
    }

    function testFail_hub_upgrade_kills_old_hub() public {
        _windSystem(); // Tests that the current pool has ink/art

        // Setup New hub
        D3MHub newHub = new D3MHub(address(daiJoin));
        newHub.file("vow", vow);
        newHub.file("end", address(end));

        newHub.file(ilk, "pool", address(d3mTestPool));
        newHub.file(ilk, "plan", address(d3mTestPlan));
        newHub.file(ilk, "tau", 7 days);

        // Update permissions on d3ms
        d3mTestPool.rely(address(newHub));
        d3mTestPool.deny(address(d3mHub));
        d3mTestPool.file("hub", address(newHub));

        // Update Permissions in Vat
        vat.deny(address(d3mHub));
        vat.rely(address(newHub));

        // Clean up old hub
        d3mHub.file(ilk, "pool", address(0));
        d3mHub.file(ilk, "plan", address(0));
        d3mHub.file(ilk, "tau", 0);

        // Ensure old hub revert
        d3mHub.exec(ilk);
    }

    function test_hub_upgrade_new_d3ms() public {
        _windSystem(); // Tests that the current pool has ink/art

        // Setup New hub and D3M
        D3MHub newHub = new D3MHub(address(daiJoin));
        newHub.file("vow", vow);
        newHub.file("end", address(end));
        vat.rely(address(newHub));

        // Setup new pool
        D3MTestPool newPool = new D3MTestPool(
            address(newHub),
            address(dai),
            address(testGem),
            address(rewardsClaimer)
        );
        newPool.rely(address(newHub));
        testGem.rely(address(newPool));
        testGem.giveAllowance(
            address(dai),
            address(newPool),
            type(uint256).max
        );

        // Setup new plan
        D3MTestPlan newPlan = new D3MTestPlan(address(dai));
        newPlan.file("maxBar_", type(uint256).max);
        newPlan.file("bar", 5);
        newPlan.file("targetAssets", 100 * WAD);

        // Create D3M in New Hub
        newHub.file(ilk, "pool", address(newPool));
        newHub.file(ilk, "plan", address(newPlan));
        (, , uint256 tau, , ) = d3mHub.ilks(ilk);
        newHub.file(ilk, "tau", tau);

        (uint256 opink, uint256 opart) = vat.urns(ilk, address(d3mTestPool));
        assertGt(opink, 0);
        assertGt(opart, 0);

        (uint256 npink, uint256 npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 0);
        assertEq(npart, 0);
        assertTrue(newPool.preDebt() == false);
        assertTrue(newPool.postDebt() == false);

        newPool.file("hub", address(newHub));

        // Transition Balances
        d3mTestPool.quit(address(newPool));
        vat.grab(
            ilk,
            address(d3mTestPool),
            address(newPool),
            address(newPool),
            -int256(opink),
            -int256(opart)
        );
        vat.grab(
            ilk,
            address(newPool),
            address(newPool),
            address(newPool),
            int256(opink),
            int256(opart)
        );

        // Ensure we quit our position
        (opink, opart) = vat.urns(ilk, address(d3mTestPool));
        assertEq(opink, 0);
        assertEq(opart, 0);
        // quit does not call hooks
        assertTrue(d3mTestPool.preDebt() == false);
        assertTrue(d3mTestPool.postDebt() == false);

        (npink, npart) = vat.urns(ilk, address(newPool));
        assertEq(npink, 50 * WAD);
        assertEq(npart, 50 * WAD);
        assertTrue(newPool.preDebt() == false);
        assertTrue(newPool.postDebt() == false);

        // Clean up after transition
        d3mHub.cage(ilk);
        d3mTestPool.deny(address(d3mHub));
        vat.deny(address(d3mHub));

        // Ensure new hub operation
        newPlan.file("bar", 10);
        newPlan.file("targetAssets", 200 * WAD);
        newHub.exec(ilk);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(newPool));
        assertEq(ink, 200 * WAD);
        assertEq(art, 200 * WAD);
        assertTrue(newPool.preDebt());
        assertTrue(newPool.postDebt());
    }

    function cmpStr(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function test_exec_lock_protection() public {
        // Store memory slot 0x3
        vm.store(address(d3mHub), bytes32(uint256(3)), bytes32(uint256(1)));
        assertEq(d3mHub.locked(), 1);

        assertRevert(address(d3mHub), abi.encodeWithSignature("exec(bytes32)", ilk), "D3MHub/system-locked");
    }

    function test_exit_lock_protection() public {
        // Store memory slot 0x3
        vm.store(address(d3mHub), bytes32(uint256(3)), bytes32(uint256(1)));
        assertEq(d3mHub.locked(), 1);

        assertRevert(address(d3mHub), abi.encodeWithSignature("exit(bytes32,address,uint256)", ilk, address(this), 1), "D3MHub/system-locked");
    }

    function test_unwind_due_to_by_pool_loss() public {
        _windSystem(); // winds to 50 * WAD

        // Set debt ceiling to 60 to limit loss
        vat.file(ilk, "line", 60 * RAD);

        // Simulate a loss event by removing the share tokens
        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);
        assertEq(d3mTestPool.assetBalance(), 50 * WAD);

        _giveTokens(TokenLike(address(testGem)), address(d3mTestPool), 20 * WAD); // Lost 30 tokens

        assertEq(testGem.balanceOf(address(d3mTestPool)), 20 * WAD);
        assertEq(d3mTestPool.assetBalance(), 20 * WAD);
        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);

        // This should force unwind
        d3mHub.exec(ilk);

        assertEq(d3mTestPool.assetBalance(), 0);
        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 30 * WAD);
        assertEq(art, 30 * WAD);
    }

    function test_exec_fixInk_full_under_debt_ceiling() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        assertEq(d3mTestPool.maxWithdraw(), 50 * WAD);

        vat.file(ilk, "line", 55 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai + 10 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);
    }

    function test_exec_fixInk_limited_under_debt_ceiling_nothing_to_withdraw() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(0))
        );
        assertEq(d3mTestPool.maxWithdraw(), 0);

        vat.file(ilk, "line", 55 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 55 * WAD);
        assertEq(art, 55 * WAD);
        assertEq(vat.dai(vow), prevDai + 5 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
    }

    function test_exec_fixInk_limited_under_debt_ceiling_something_to_withdraw() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(3 * WAD))
        );
        assertEq(d3mTestPool.maxWithdraw(), 3 * WAD);

        vat.file(ilk, "line", 55 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 55 * WAD);
        assertEq(art, 55 * WAD);
        assertEq(vat.dai(vow), prevDai + 8 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 57 * WAD);
    }

    function test_exec_fixInk_full_at_debt_ceiling() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        assertEq(d3mTestPool.maxWithdraw(), 50 * WAD);

        vat.file(ilk, "line", 50 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai + 10 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);
    }

    function test_exec_fixInk_limited_at_debt_ceiling_nothing_to_withdraw() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(0))
        );
        assertEq(d3mTestPool.maxWithdraw(), 0);

        vat.file(ilk, "line", 50 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
    }

    function test_exec_fixInk_limited_at_debt_ceiling_something_to_withdraw() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(3 * WAD))
        );
        assertEq(d3mTestPool.maxWithdraw(), 3 * WAD);

        vat.file(ilk, "line", 50 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai + 3 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 57 * WAD);
    }

    function test_exec_fixInk_full_above_debt_ceiling() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(10 * WAD))
        );
        assertEq(d3mTestPool.maxWithdraw(), 10 * WAD);

        vat.file(ilk, "line", 45 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai + 10 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 50 * WAD);
    }

    function test_exec_fixInk_limited_above_debt_ceiling_nothing_to_withdraw() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(0))
        );
        assertEq(d3mTestPool.maxWithdraw(), 0);

        vat.file(ilk, "line", 45 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
    }

    function test_exec_fixInk_limited_above_debt_ceiling_something_to_withdraw() public {
        _windSystem();
        // interest is determined by the difference in gem balance to dai debt
        // by giving extra gems to the Join we simulate interest
        _giveTokens(TokenLike(address(testGem)), 10 * WAD);
        testGem.transfer(address(d3mTestPool), 10 * WAD); // Simulates 10 WAD of interest accumulated
        assertEq(testGem.balanceOf(address(d3mTestPool)), 60 * WAD);
        vm.store(
            address(dai),
            keccak256(abi.encode(address(testGem), uint256(2))),
            bytes32(uint256(3 * WAD))
        );
        assertEq(d3mTestPool.maxWithdraw(), 3 * WAD);

        vat.file(ilk, "line", 45 * RAD);

        (uint256 ink, uint256 art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        uint256 prevDai = vat.dai(vow);

        d3mHub.exec(ilk);

        (ink, art) = vat.urns(ilk, address(d3mTestPool));
        assertEq(ink, 50 * WAD);
        assertEq(art, 50 * WAD);
        assertEq(vat.dai(vow), prevDai + 3 * RAD);
        assertEq(testGem.balanceOf(address(d3mTestPool)), 57 * WAD);
    }

    function test_exec_different_art_Art() public {
        vat.slip(ilk, address(this), int256(1));
        vat.frob(ilk, address(this), address(this), address(this), int256(1), int256(1));
        assertRevert(address(d3mHub), abi.encodeWithSignature("exec(bytes32)", bytes32("fake-ilk")), "D3MHub/rate-not-one");
    }

    function test_culled_not_reverting_different_art_Art() public {
        vat.slip(ilk, address(this), int256(1));
        vat.frob(ilk, address(this), address(this), address(this), int256(1), int256(1));
        d3mHub.cage(ilk);
        d3mHub.cull(ilk);
        d3mHub.exec(ilk);
    }

    function test_system_caged_not_reverting_different_art_Art() public {
        vat.slip(ilk, address(this), int256(1));
        vat.frob(ilk, address(this), address(this), address(this), int256(1), int256(1));
        end.cage();
        end.cage(ilk);
        d3mHub.exec(ilk);
    }

    function test_cage_ilk_after_uncull() public {
        _windSystem();
        d3mHub.cage(ilk);
        d3mHub.cull(ilk);
        end.cage();
        d3mHub.uncull(ilk);
        end.cage(ilk);
    }

    function test_cage_ilk_before_uncull() public {
        _windSystem();
        d3mHub.cage(ilk);
        d3mHub.cull(ilk);
        end.cage();
        assertRevert(address(end), abi.encodeWithSignature("cage(bytes32)", ilk), "D3MOracle/ilk-culled-in-shutdown");
    }
}
