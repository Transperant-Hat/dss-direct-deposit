// D3MHub.spec

using Vat as vat
using Dai as dai
using DaiJoin as daiJoin
using End as end
using D3MTestPool as pool
using D3MTestPlan as plan
using D3MTestGem as share

methods {
    vat() returns (address) envfree
    daiJoin() returns (address) envfree
    vow() returns (address) envfree
    end() returns (address) envfree
    ilks(bytes32) returns (address, address, uint256, uint256, uint256) envfree
    locked() returns (uint256) envfree
    plan(bytes32) returns (address) envfree => DISPATCHER(true)
    pool(bytes32) returns (address) envfree => DISPATCHER(true)
    tic(bytes32) returns (uint256) envfree
    tau(bytes32) returns (uint256) envfree
    culled(bytes32) returns (uint256) envfree
    wards(address) returns (uint256) envfree
    vat.can(address, address) returns (uint256) envfree
    vat.debt() returns (uint256) envfree
    vat.dai(address) returns (uint256) envfree
    vat.gem(bytes32, address) returns (uint256) envfree
    vat.Line() returns (uint256) envfree
    vat.live() returns (uint256) envfree
    vat.ilks(bytes32) returns (uint256, uint256, uint256, uint256, uint256) envfree
    vat.sin(address) returns (uint256) envfree
    vat.urns(bytes32, address) returns (uint256, uint256) envfree
    vat.vice() returns (uint256) envfree
    vat.wards(address) returns (uint256) envfree
    dai.allowance(address, address) returns (uint256) envfree
    dai.balanceOf(address) returns (uint256) envfree
    dai.totalSupply() returns (uint256) envfree
    dai.wards(address) returns (uint256) envfree
    daiJoin.dai() returns (address) envfree
    daiJoin.live() returns (uint256) envfree
    daiJoin.vat() returns (address) envfree
    end.debt() returns (uint256) envfree
    end.gap(bytes32) returns (uint256) envfree
    end.tag(bytes32) returns (uint256) envfree
    end.vat() returns (address) envfree
    end.vow() returns (address) envfree
    plan.dai() returns (address) envfree
    pool.hub() returns (address) envfree
    pool.vat() returns (address) envfree
    pool.dai() returns (address) envfree
    pool.share() returns (address) envfree
    share.balanceOf(address) returns (uint256) envfree
    share.totalSupply() returns (uint256) envfree
    share.wards(address) returns (uint256) envfree
    debt() returns (uint256) => DISPATCHER(true)
    skim(bytes32, address) => DISPATCHER(true)
    active() returns (bool) => DISPATCHER(true)
    getTargetAssets(uint256) returns (uint256) => DISPATCHER(true)
    assetBalance() returns (uint256) => DISPATCHER(true)
    maxDeposit() returns (uint256) => DISPATCHER(true)
    maxWithdraw() returns (uint256) => DISPATCHER(true)
    deposit(uint256) => DISPATCHER(true)
    withdraw(uint256) => DISPATCHER(true)
    preDebtChange() => DISPATCHER(true)
    postDebtChange() => DISPATCHER(true)
    exit(address, uint256) => DISPATCHER(true)
    balanceOf(address) returns (uint256) => DISPATCHER(true)
    burn(address, uint256) => DISPATCHER(true)
    mint(address, uint256) => DISPATCHER(true)
}

definition WAD() returns uint256 = 10^18;
definition RAY() returns uint256 = 10^27;

definition min_int256() returns mathint = -1 * 2^255;
definition max_int256() returns mathint = 2^255 - 1;
definition safe_max() returns mathint = max_int256() / RAY();

definition min(mathint x, mathint y) returns mathint = x < y ? x : y;
definition max(mathint x, mathint y) returns mathint = x > y ? x : y;

definition divup(mathint x, mathint y) returns mathint = x != 0 ? ((x - 1) / y) + 1 : 0;

rule rely(address usr) {
    env e;

    address other;
    require(other != usr);
    uint256 wardOther = wards(other);

    rely(e, usr);

    assert(wards(usr) == 1, "rely did not set the wards as expected");
    assert(wards(other) == wardOther, "rely affected other wards which wasn't expected");
}

rule rely_revert(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");

    assert(lastReverted => revert1 || revert2, "Revert rules are not covering all the cases");
}

rule deny(address usr) {
    env e;

    address other;
    require(other != usr);
    uint256 wardOther = wards(other);

    deny(e, usr);

    assert(wards(usr) == 0, "deny did not set the wards as expected");
    assert(wards(other) == wardOther, "deny affected other wards which wasn't expected");
}

rule deny_revert(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");

    assert(lastReverted => revert1 || revert2, "Revert rules are not covering all the cases");
}

rule file_ilk_uint256(bytes32 ilk, bytes32 what, uint256 data) {
    env e;

    file(e, ilk, what, data);

    assert(tau(ilk) == data, "file did not set tau as expected");
}

rule file_ilk_uint256_revert(bytes32 ilk, bytes32 what, uint256 data) {
    env e;

    uint256 ward = wards(e.msg.sender);

    file@withrevert(e, ilk, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = what != 0x7461750000000000000000000000000000000000000000000000000000000000;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");

    assert(lastReverted => revert1 || revert2 || revert3, "Revert rules are not covering all the cases");
}

rule file_ilk_address(bytes32 ilk, bytes32 what, address data) {
    env e;

    file(e, ilk, what, data);

    assert(what == 0x706f6f6c00000000000000000000000000000000000000000000000000000000 => pool(ilk) == data, "file did not set pool as expected");
    assert(what == 0x706c616e00000000000000000000000000000000000000000000000000000000 => plan(ilk) == data, "file did not set plan as expected");
}

rule file_ilk_address_revert(bytes32 ilk, bytes32 what, address data) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 vatLive = vat.live();
    uint256 tic = tic(ilk);

    file@withrevert(e, ilk, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = vatLive != 1;
    bool revert4 = tic != 0;
    bool revert5 = what != 0x706f6f6c00000000000000000000000000000000000000000000000000000000 && what != 0x706c616e00000000000000000000000000000000000000000000000000000000;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");
    assert(revert5 => lastReverted, "revert5 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5, "Revert rules are not covering all the cases");
}

rule ilk_getters() {
    bytes32 ilk;
    address pool_; address plan_; uint256 tau; uint256 culled; uint256 tic;
    pool_, plan_, tau, culled, tic = ilks(ilk);
    assert(pool_ == pool(ilk), "pool getter did not return ilk.pool");
    assert(plan_ == plan(ilk), "plan getter did not return ilk.plan");
    assert(tau == tau(ilk), "tau getter did not return ilk.tau");
    assert(culled == culled(ilk), "culled getter did not return ilk.culled");
    assert(tic == tic(ilk), "tic getter did not return ilk.tic");
}

rule exec_normal(bytes32 ilk) {
    env e;

    address vow = vow();

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(vow != daiJoin);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 tic = tic(ilk);
    uint256 culled = culled(ilk);

    uint256 LineBefore = vat.Line();
    uint256 debtBefore = vat.debt();
    uint256 ArtBefore;
    uint256 rateBefore;
    uint256 spotBefore;
    uint256 lineBefore;
    uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = vat.ilks(ilk);
    uint256 inkBefore;
    uint256 artBefore;
    inkBefore, artBefore = vat.urns(ilk, pool);

    bool active = plan.active(e);
    uint256 maxDeposit = pool.maxDeposit(e);
    mathint maxWithdraw = min(to_mathint(pool.maxWithdraw(e)), safe_max());
    uint256 assetsBefore = pool.assetBalance(e);
    uint256 targetAssets = plan.getTargetAssets(e, assetsBefore);
    uint256 vatDaiVowBefore = vat.dai(vow);

    require(vat.live() == 1);
    require(culled == 0);

    exec(e, ilk);

    uint256 LineAfter = vat.Line();
    uint256 debtAfter = vat.debt();
    uint256 ArtAfter;
    uint256 rateAfter;
    uint256 spotAfter;
    uint256 lineAfter;
    uint256 dustAfter;
    ArtAfter, rateAfter, spotAfter, lineAfter, dustAfter = vat.ilks(ilk);
    uint256 inkAfter;
    uint256 artAfter;
    inkAfter, artAfter = vat.urns(ilk, pool);

    uint256 assetsAfter = pool.assetBalance(e);
    uint256 vatDaiVowAfter = vat.dai(vow);

    uint256 lineWad = lineBefore / RAY();
    uint256 underLine = inkBefore < lineWad ? lineWad - inkBefore : 0;
    mathint fixInk = assetsBefore > inkBefore
                     ?  min(
                            min(
                                assetsBefore - inkBefore,
                                underLine + maxWithdraw
                            ),
                            safe_max() + artBefore - inkBefore
                        )
                     : 0;
    mathint fixArt = inkBefore + fixInk - artBefore;
    mathint debtMiddle = debtBefore + fixArt * RAY();

    // General asserts
    assert(LineAfter == LineBefore, "Line should not change");
    assert(lineAfter == lineBefore, "line should not change");
    assert(artAfter == ArtAfter, "art should be same than Art");
    assert(inkAfter == artAfter, "ink and art should end up being the same");
    assert(inkAfter <= lineWad || inkAfter <= inkBefore, "ink can not overpass debt ceiling or be higher than prev one");
    assert(inkAfter <= safe_max(), "ink can not overpass max_int256 / RAY");
    assert(vatDaiVowAfter == vatDaiVowBefore + fixArt * RAY(), "vatDaiVow did not increase as expected");
    // Winding to targetAssets
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        maxDeposit >= targetAssets - assetsBefore && // target IS NOT restricted by maxDeposit
        targetAssets <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore // target IS NOT restricted by global Line
            => artAfter == targetAssets &&
               assetsAfter == artAfter,
               "wind: error 1"
    );
    assert(
        tic == 0 && active && inkBefore > assetsBefore && inkBefore - assetsBefore <= WAD() && // regular path in normal path but assets right below ink
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        maxDeposit >= targetAssets - assetsBefore && // target IS NOT restricted by maxDeposit
        targetAssets + (inkBefore - assetsBefore) <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore // target IS NOT restricted by global Line
            => artAfter == targetAssets + (inkBefore - assetsBefore) &&
               assetsAfter == targetAssets,
               "wind: error 2"
    );
    // Winding to ilk line
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        maxDeposit >= targetAssets - assetsBefore && // target IS NOT restricted by maxDeposit
        targetAssets > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        inkBefore <= lineWad // ink before execution is safe under ilk line
            => artAfter == lineWad &&
               assetsAfter >= artAfter,
               "wind: error 3"
    );
    assert(
        tic == 0 && active && inkBefore > assetsBefore && inkBefore - assetsBefore <= WAD() && // regular path in normal path but assets right below ink
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        maxDeposit >= targetAssets - assetsBefore && // target IS NOT restricted by maxDeposit
        targetAssets + (inkBefore - assetsBefore) > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        inkBefore <= lineWad // ink before execution is safe under ilk line
            => artAfter == lineWad &&
               assetsAfter == artAfter - (inkBefore - assetsBefore),
               "wind: error 4"
    );
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        maxDeposit >= targetAssets - assetsBefore && // target IS NOT restricted by maxDeposit
        targetAssets > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        assetsBefore <= lineWad && // assets before execution is safe under ilk line
        targetAssets >= lineWad // target is pointed above ilk line
            => artAfter == lineWad &&
               assetsAfter == artAfter,
               "wind: error 5"
    );
    // Unwinding to targetAssets
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets <= assetsBefore && // plan determines we need to go down (or keep the same)
        targetAssets <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= 0 && // target IS NOT restricted by global Line
        maxWithdraw >= assetsBefore - targetAssets && // target IS NOT restricted by maxWithdraw
        assetsBefore <= safe_max() // target is NOT restricted by safe maxint256 wad
            => artAfter == targetAssets &&
               assetsAfter == artAfter,
               "unwind: error 1"
    );
    assert(
        tic == 0 && active && inkBefore > assetsBefore && inkBefore - assetsBefore <= WAD() && // regular path in normal path but assets right below ink
        targetAssets <= assetsBefore && // plan determines we need to go down (or keep the same)
        targetAssets + (inkBefore - assetsBefore) <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= 0 && // target IS NOT restricted by global Line
        maxWithdraw >= assetsBefore - targetAssets && // target IS NOT restricted by maxWithdraw
        assetsBefore <= safe_max() // target is NOT restricted by safe maxint256 wad
            => artAfter == targetAssets + (inkBefore - assetsBefore) &&
               assetsAfter == targetAssets,
               "unwind: error 2"
    );
    // Unwinding due to targetAssets but restricted
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets <= assetsBefore && // plan determines we need to go down (or keep the same)
        targetAssets <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= 0 && // target IS NOT restricted by global Line
        maxWithdraw < assetsBefore - targetAssets && // target IS restricted by maxWithdraw
        assetsBefore <= lineWad
            => artAfter == assetsBefore - maxWithdraw &&
               assetsAfter == artAfter,
               "unwind: error 3"
    );
    assert(
        tic == 0 && active && inkBefore > assetsBefore && inkBefore - assetsBefore <= WAD() && // regular path in normal path but assets right below ink
        targetAssets <= assetsBefore && // plan determines we need to go down (or keep the same)
        targetAssets <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= 0 && // target IS NOT restricted by global Line
        maxWithdraw < assetsBefore - targetAssets && // target IS restricted by maxWithdraw
        assetsBefore <= lineWad
            => artAfter == assetsAfter + (inkBefore - assetsBefore) &&
               assetsAfter == assetsBefore - maxWithdraw,
               "unwind: error 4"
    );
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets <= assetsBefore && // plan determines we need to go down (or keep the same)
        targetAssets <= lineWad && // target IS NOT restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= 0 && // target IS NOT restricted by global Line
        maxWithdraw < assetsBefore - targetAssets && // target IS restricted by maxWithdraw
        assetsBefore <= safe_max() && // target is NOT restricted by safe maxint256 wad
        inkBefore > lineWad && // ink before execution is not safe (over ilk line)
        assetsBefore - inkBefore > maxWithdraw
            => artAfter == inkBefore,
               "unwind: error 5"
    );
    // Unwinding due to line
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        targetAssets > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        assetsBefore <= safe_max() && // target is NOT restricted by safe maxint256 wad
        inkBefore > lineWad && // ink before execution is not safe (over ilk line)
        maxWithdraw >= assetsBefore - lineWad // enough to rebalance and decrease to ilk line value
            => artAfter == lineWad &&
               assetsAfter == artAfter,
               "unwind: error 6"
    );
    assert(
        tic == 0 && active && inkBefore > assetsBefore && inkBefore - assetsBefore <= WAD() && // regular path in normal path but assets right below ink
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        targetAssets + (inkBefore - assetsBefore) > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        assetsBefore <= safe_max() && // target is NOT restricted by safe maxint256 wad
        inkBefore > lineWad && // ink before execution is not safe (over ilk line)
        maxWithdraw >= inkBefore - lineWad // enough to rebalance and decrease to ilk line value
            => artAfter == lineWad &&
               assetsAfter == artAfter - (inkBefore - assetsBefore),
               "unwind: error 7"
    );
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        targetAssets > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        inkBefore > lineWad && // ink before execution is not safe (over ilk line)
        assetsBefore <= safe_max() && // target is NOT restricted by safe maxint256 wad
        maxWithdraw < assetsBefore - inkBefore // NOT enough for full rebalance
            => artAfter == inkBefore &&
               assetsAfter > artAfter,
               "unwind: error 8"
    );
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        targetAssets > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        inkBefore > lineWad && // ink before execution is not safe (over ilk line)
        maxWithdraw < inkBefore - lineWad // no way to decrease to ilk line value
            => artAfter == inkBefore + fixInk - maxWithdraw &&
               assetsAfter >= artAfter,
               "unwind: error 9"
    );
    assert(
        tic == 0 && active && assetsBefore >= inkBefore && // regular path in normal path
        targetAssets >= assetsBefore && // plan determines we need to go up (or keep the same)
        targetAssets > lineWad && // target IS restricted by ilk line
        (LineBefore - debtMiddle) / RAY() >= targetAssets - assetsBefore && // target IS NOT restricted by global Line
        inkBefore > lineWad && // ink before execution is not safe (over ilk line)
        assetsBefore <= safe_max() && // target is NOT restricted by safe maxint256 wad
        maxWithdraw < assetsBefore - lineWad && // NOT enough to rebalance and decrease to ilk line value
        maxWithdraw >= assetsBefore - inkBefore // enough for full rebalance
            => artAfter == assetsBefore - maxWithdraw &&
               artAfter <= inkBefore &&
               artAfter >= lineWad &&
               assetsAfter == artAfter,
               "unwind: error 10"
    );
    // Force unwinding due to ilk caged (but not culled yet) or plan inactive or assets being missing:
    assert(
        (tic > 0 || !active || assetsBefore + WAD() < inkBefore) &&
        assetsBefore <= safe_max() && // full unwinding is NOT restricted by safe maxint256 wad
        assetsBefore >= inkBefore &&
        assetsBefore <= maxWithdraw
            => artAfter == 0, "unwind: error 11"
    );
    assert(
        (tic > 0 || !active || assetsBefore + WAD() < inkBefore) &&
        assetsBefore <= safe_max() && // full unwinding is NOT restricted by safe maxint256 wad
        assetsBefore >= inkBefore &&
        assetsBefore > maxWithdraw &&
        assetsBefore - maxWithdraw < lineWad
            => artAfter == assetsBefore - maxWithdraw, "unwind: error 12"
    );
    assert(
        (tic > 0 || !active || assetsBefore + WAD() < inkBefore) &&
        assetsBefore <= safe_max() && // full unwinding is NOT restricted by safe maxint256 wad
        assetsBefore > maxWithdraw &&
        assetsBefore - maxWithdraw >= lineWad &&
        inkBefore <= lineWad
            => artAfter == lineWad, "unwind: error 13"
    );
    assert(
        (tic > 0 || !active || assetsBefore + WAD() < inkBefore) &&
        assetsBefore <= safe_max() && // full unwinding is NOT restricted by safe maxint256 wad
        assetsBefore > maxWithdraw &&
        assetsBefore - maxWithdraw >= inkBefore &&
        inkBefore > lineWad
            => artAfter == inkBefore, "unwind: error 14"
    );
}

rule exec_normal_revert(bytes32 ilk) {
    env e;

    address vow = vow();

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(vow != currentContract);
    require(vow != daiJoin);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 locked = locked();
    uint256 Line = vat.Line();
    uint256 Art;
    uint256 rate;
    uint256 spot;
    uint256 line;
    uint256 dust;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    uint256 ink;
    uint256 art;
    ink, art = vat.urns(ilk, pool);
    uint256 assets = pool.assetBalance(e);

    require(vat.live() == 1);
    require(culled(ilk) == 0);
    require(dust == 0);
    require(dai.wards(daiJoin) == 1);
    require(share.wards(pool) == 1);

    mathint maxWithdraw = min(to_mathint(pool.maxWithdraw(e)), safe_max());
    uint256 maxDeposit = pool.maxDeposit(e);
    uint256 lineWad = line / RAY();
    uint256 debt = vat.debt();
    uint256 underLine = ink < lineWad ? lineWad - ink : 0;
    mathint fixInk = assets > ink
                     ?  min(
                            min(
                                assets - ink,
                                underLine + maxWithdraw
                            ),
                            safe_max() + art - ink >= 0 ? safe_max() + art - ink : 0
                        )
                     : 0;
    mathint inkFixed = ink + fixInk;
    mathint fixArt = inkFixed - art;
    mathint artFixed = art + fixArt;
    mathint debtMiddle = debt + fixArt * RAY();

    uint256 tic = tic(ilk);
    bool active = plan.active(e);

    uint256 targetAssets = plan.getTargetAssets(e, assets);

    mathint toUnwindAux = max(
                            max(
                                artFixed > lineWad ? artFixed - to_mathint(lineWad) : 0,
                                debtMiddle > Line ? divup(debtMiddle - to_mathint(Line), to_mathint(RAY())) : 0
                            ),
                            targetAssets < assets ? to_mathint(assets - targetAssets) : 0
                        );

    mathint toUnwind = (tic > 0 || !active || assets + WAD() < ink)
                        ? maxWithdraw
                        : min(toUnwindAux, maxWithdraw);

    mathint toWind = tic == 0 && active && assets + WAD() >= ink && toUnwindAux == 0
                    ? min(
                        to_mathint(lineWad - artFixed),
                        min(
                            (to_mathint(Line) - debtMiddle) / to_mathint(RAY()),
                            min(
                                to_mathint(targetAssets - assets),
                                to_mathint(maxDeposit)
                            )
                        )
                    )
                    : 0;

    uint256 vatGemPool = vat.gem(ilk, pool);
    require(ink == 0 || vatGemPool == 0); // To ensure correct behavior
    uint256 vatWardHub = vat.wards(currentContract);
    uint256 shareBalPool = share.balanceOf(pool);
    uint256 shareSupply = share.totalSupply();
    require(shareSupply >= shareBalPool); // To ensure correct behaviour
    uint256 daiBalShare = dai.balanceOf(share);
    uint256 daiBalPool = dai.balanceOf(pool);
    uint256 daiSupply = dai.totalSupply();
    require(daiSupply >= daiBalShare + daiBalPool); // To ensure correct behaviour
    uint256 daiAllowanceSharePool = dai.allowance(share, pool);
    uint256 daiBalHub = dai.balanceOf(currentContract);
    uint256 vatDaiDaiJoin = vat.dai(daiJoin);
    uint256 vatDaiHub = vat.dai(currentContract);
    uint256 daiAllowanceHubDaiJoin = dai.allowance(currentContract, daiJoin);
    uint256 vatSinVow = vat.sin(vow);
    uint256 vatDaiVow = vat.dai(vow);
    uint256 vatVice = vat.vice();
    uint256 vatDebt = vat.debt();
    require(vatDebt >= art * rate); // To ensure correct behaviour
    uint256 vatCanPoolHub = vat.can(pool, currentContract);
    uint256 vatCanHubDaiJoin = vat.can(currentContract, daiJoin);
    uint256 daiJoinLive = daiJoin.live();

    exec@withrevert(e, ilk);

    bool revert1  = e.msg.value > 0;
    bool revert2  = locked != 0;
    bool revert3  = rate != RAY();
    bool revert4  = spot != RAY();
    bool revert5  = lineWad > safe_max();
    bool revert6  = ink > safe_max();
    bool revert7  = ink < art;
    bool revert8  = art != Art;
    bool revert9  = assets > ink && ink < lineWad && (lineWad - ink) + maxWithdraw > max_uint256;
    bool revert10 = assets > ink && fixInk > max_int256();
    // vat.slip:
    bool revert11 = assets > ink && vatWardHub != 1;
    bool revert12 = assets > ink && vatGemPool + fixInk > max_uint256;
    // vat.frob:
    bool revert13 = assets > ink && fixInk > 0 && vatCanPoolHub != 1;
    // vat.suck:
    bool revert14 = art < inkFixed && vatWardHub != 1;
    bool revert15 = art < inkFixed && vatSinVow + rate * fixArt > max_uint256;
    bool revert16 = art < inkFixed && vatDaiVow + rate * fixArt > max_uint256;
    bool revert17 = art < inkFixed && vatVice + rate * fixArt > max_uint256;
    bool revert18 = art < inkFixed && vatDebt + rate * fixArt > max_uint256;
    //
    bool revert19 = tic == 0 && active && assets + WAD() > max_uint256;
    // pool.withdraw:
    bool revert20 = toUnwind > 0 && shareBalPool < toUnwind;
    bool revert21 = toUnwind > 0 && daiBalShare < toUnwind;
    bool revert22 = toUnwind > 0 && daiAllowanceSharePool < toUnwind;
    bool revert23 = toUnwind > 0 && daiBalHub + toUnwind > max_uint256;
    // daiJoin.join:
    bool revert24 = toUnwind > 0 && vatDaiDaiJoin < toUnwind * RAY();
    bool revert25 = toUnwind > 0 && vatDaiHub + toUnwind * RAY() > max_uint256;
    bool revert26 = toUnwind > 0 && daiAllowanceHubDaiJoin < toUnwind;
    // vat.frob:
    bool revert27 = toUnwind > 0 && vatCanPoolHub != 1;
    // vat.slip:
    bool revert28 = toUnwind > 0 && vatWardHub != 1;
    //
    bool revert29 = toWind > 0 && artFixed + toWind > safe_max();
    // vat.slip:
    bool revert30 = toWind > 0 && vatWardHub != 1;
    bool revert31 = toWind > 0 && vatGemPool + toWind > max_uint256;
    // vat.frob:
    bool revert32 = toWind > 0 && vatCanPoolHub != 1;
    bool revert33 = toWind > 0 && vatDaiHub + rate * toWind > max_uint256;
    // daiJoin.exit:
    bool revert34 = toWind > 0 && daiJoinLive != 1;
    bool revert35 = toWind > 0 && vatCanHubDaiJoin != 1;
    bool revert36 = toWind > 0 && vatDaiDaiJoin + toWind * RAY() > max_uint256;
    bool revert37 = toWind > 0 && daiSupply + toWind > max_uint256;
    // pool.deposit:
    bool revert38 = toWind > 0 && shareSupply + toWind > max_uint256;

    assert(revert1  => lastReverted, "revert1 failed");
    assert(revert2  => lastReverted, "revert2 failed");
    assert(revert3  => lastReverted, "revert3 failed");
    assert(revert4  => lastReverted, "revert4 failed");
    assert(revert5  => lastReverted, "revert5 failed");
    assert(revert6  => lastReverted, "revert6 failed");
    assert(revert7  => lastReverted, "revert7 failed");
    assert(revert8  => lastReverted, "revert8 failed");
    assert(revert9  => lastReverted, "revert9 failed");
    assert(revert10 => lastReverted, "revert10 failed");
    assert(revert11 => lastReverted, "revert11 failed");
    assert(revert12 => lastReverted, "revert12 failed");
    assert(revert13 => lastReverted, "revert13 failed");
    assert(revert14 => lastReverted, "revert14 failed");
    assert(revert15 => lastReverted, "revert15 failed");
    assert(revert16 => lastReverted, "revert16 failed");
    assert(revert17 => lastReverted, "revert17 failed");
    assert(revert18 => lastReverted, "revert18 failed");
    assert(revert19 => lastReverted, "revert19 failed");
    assert(revert20 => lastReverted, "revert20 failed");
    assert(revert21 => lastReverted, "revert21 failed");
    assert(revert22 => lastReverted, "revert22 failed");
    assert(revert23 => lastReverted, "revert23 failed");
    assert(revert24 => lastReverted, "revert24 failed");
    assert(revert25 => lastReverted, "revert25 failed");
    assert(revert26 => lastReverted, "revert26 failed");
    assert(revert27 => lastReverted, "revert27 failed");
    assert(revert28 => lastReverted, "revert28 failed");
    assert(revert29 => lastReverted, "revert29 failed");
    assert(revert30 => lastReverted, "revert30 failed");
    assert(revert31 => lastReverted, "revert31 failed");
    assert(revert32 => lastReverted, "revert32 failed");
    assert(revert33 => lastReverted, "revert33 failed");
    assert(revert34 => lastReverted, "revert34 failed");
    assert(revert35 => lastReverted, "revert35 failed");
    assert(revert36 => lastReverted, "revert36 failed");
    assert(revert37 => lastReverted, "revert37 failed");
    assert(revert38 => lastReverted, "revert38 failed");

    assert(lastReverted => revert1  || revert2  || revert3  ||
                           revert4  || revert5  || revert6  ||
                           revert7  || revert8  || revert9  ||
                           revert10 || revert11 || revert12 ||
                           revert13 || revert14 || revert15 ||
                           revert16 || revert17 || revert18 ||
                           revert19 || revert20 || revert21 ||
                           revert22 || revert23 || revert24 ||
                           revert25 || revert26 || revert27 ||
                           revert28 || revert29 || revert30 ||
                           revert31 || revert32 || revert33 ||
                           revert34 || revert35 || revert36 ||
                           revert37 || revert38, "Revert rules are not covering all the cases");
}

rule exec_ilk_culled(bytes32 ilk) {
    env e;

    address vow = vow();

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(vow != daiJoin);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 LineBefore = vat.Line();
    uint256 debtBefore = vat.debt();
    uint256 ArtBefore;
    uint256 rateBefore;
    uint256 spotBefore;
    uint256 lineBefore;
    uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = vat.ilks(ilk);
    uint256 inkBefore;
    uint256 artBefore;
    inkBefore, artBefore = vat.urns(ilk, pool);

    uint256 maxWithdraw = pool.maxWithdraw(e);
    uint256 assetsBefore = pool.assetBalance(e);
    uint256 targetAssets = plan.getTargetAssets(e, assetsBefore);

    require(vat.live() == 1);
    require(inkBefore >= artBefore);
    require(assetsBefore >= inkBefore);

    cull(e, ilk);

    uint256 vatGemPoolBefore = vat.gem(ilk, pool);
    uint256 vatDaiVowBefore = vat.dai(vow);

    exec(e, ilk);

    uint256 LineAfter = vat.Line();
    uint256 debtAfter = vat.debt();
    uint256 ArtAfter;
    uint256 rateAfter;
    uint256 spotAfter;
    uint256 lineAfter;
    uint256 dustAfter;
    ArtAfter, rateAfter, spotAfter, lineAfter, dustAfter = vat.ilks(ilk);
    uint256 inkAfter;
    uint256 artAfter;
    inkAfter, artAfter = vat.urns(ilk, pool);

    uint256 assetsAfter = pool.assetBalance(e);

    uint256 vatGemPoolAfter = vat.gem(ilk, pool);
    uint256 vatDaiVowAfter = vat.dai(vow);

    // General asserts
    assert(LineAfter == LineBefore, "Line should not change");
    assert(lineAfter == lineBefore, "line should not change");
    assert(artAfter == 0, "art should end up being 0");
    assert(inkAfter == 0, "ink should end up being 0");

    assert(assetsAfter == 0 || assetsAfter == assetsBefore - maxWithdraw, "assets should be 0 or decreased by maxWithdraw");
    assert(vatGemPoolAfter == 0 || vatGemPoolAfter == vatGemPoolBefore - maxWithdraw, "vatGemPool should be 0 or decreased by maxWithdraw");
    assert(vatDaiVowAfter == vatDaiVowBefore + (assetsBefore - assetsAfter) * RAY(), "vatDaiVow did not increase as expected");
}

rule exec_ilk_culled_revert(bytes32 ilk) {
    env e;

    address vow = vow();

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(vow != daiJoin);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 locked = locked();
    uint256 Art;
    uint256 rate;
    uint256 spot;
    uint256 line;
    uint256 dust;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    uint256 ink;
    uint256 art;
    ink, art = vat.urns(ilk, pool);
    require(Art >= art);

    uint256 maxWithdraw = pool.maxWithdraw(e);
    uint256 assets = pool.assetBalance(e);

    require(vat.live() == 1);
    require(ink >= art);
    require(assets >= ink);

    cull(e, ilk);

    uint256 vatGemPool = vat.gem(ilk, pool);
    require(ink == 0 || vatGemPool == 0); // To ensure correct behavior
    uint256 toSlip = vatGemPool < maxWithdraw ? vatGemPool : maxWithdraw;
    uint256 vatWardHub = vat.wards(currentContract);
    uint256 shareBalPool = share.balanceOf(pool);
    uint256 shareSupply = share.totalSupply();
    require(shareSupply >= shareBalPool); // To ensure correct behaviour
    uint256 daiBalShare = dai.balanceOf(share);
    uint256 daiSupply = dai.totalSupply();
    require(daiSupply >= daiBalShare); // To ensure correct behaviour
    uint256 daiAllowanceSharePool = dai.allowance(share, pool);
    uint256 daiBalHub = dai.balanceOf(currentContract);
    uint256 vatDaiDaiJoin = vat.dai(daiJoin);
    uint256 daiAllowanceHubDaiJoin = dai.allowance(currentContract, daiJoin);
    uint256 vatDaiHub = vat.dai(currentContract);
    uint256 vatDaiVow = vat.dai(vow);

    exec@withrevert(e, ilk);

    bool revert1  = e.msg.value > 0;
    bool revert2  = locked != 0;
    bool revert3  = rate != RAY();
    bool revert4  = spot != RAY();
    bool revert5  = maxWithdraw > 0 && vatWardHub != 1;
    bool revert6  = maxWithdraw > 0 && shareBalPool < maxWithdraw;
    bool revert7  = maxWithdraw > 0 && daiBalShare < maxWithdraw;
    bool revert8  = maxWithdraw > 0 && daiAllowanceSharePool < maxWithdraw;
    bool revert9  = maxWithdraw > 0 && daiBalHub + maxWithdraw > max_uint256;
    bool revert10 = maxWithdraw > 0 && maxWithdraw * RAY() > max_uint256;
    bool revert11 = maxWithdraw > 0 && vatDaiDaiJoin < maxWithdraw * RAY();
    bool revert12 = maxWithdraw > 0 && daiAllowanceHubDaiJoin < maxWithdraw;
    bool revert13 = maxWithdraw > 0 && vatDaiHub + maxWithdraw * RAY() > max_uint256;
    bool revert14 = maxWithdraw > 0 && vatDaiVow + maxWithdraw * RAY() > max_uint256;

    assert(revert1  => lastReverted, "revert1 failed");
    assert(revert2  => lastReverted, "revert2 failed");
    assert(revert3  => lastReverted, "revert3 failed");
    assert(revert4  => lastReverted, "revert4 failed");
    assert(revert5  => lastReverted, "revert5 failed");
    assert(revert6  => lastReverted, "revert6 failed");
    assert(revert7  => lastReverted, "revert7 failed");
    assert(revert8  => lastReverted, "revert8 failed");
    assert(revert9  => lastReverted, "revert9 failed");
    assert(revert10 => lastReverted, "revert10 failed");
    assert(revert11 => lastReverted, "revert11 failed");
    assert(revert12 => lastReverted, "revert12 failed");
    assert(revert13 => lastReverted, "revert13 failed");
    assert(revert14 => lastReverted, "revert14 failed");

    assert(lastReverted => revert1  || revert2  || revert3  ||
                           revert4  || revert5  || revert6  ||
                           revert7  || revert8  || revert9  ||
                           revert10 || revert11 || revert12 ||
                           revert13 || revert14, "Revert rules are not covering all the cases");
}

rule exec_vat_caged(bytes32 ilk) {
    env e;

    address vow = vow();

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(end() == end);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(vow != daiJoin);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(end.vat() == vat);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 LineBefore = vat.Line();
    uint256 debtBefore = vat.debt();
    uint256 ArtBefore;
    uint256 rateBefore;
    uint256 spotBefore;
    uint256 lineBefore;
    uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = vat.ilks(ilk);
    uint256 inkBefore;
    uint256 artBefore;
    inkBefore, artBefore = vat.urns(ilk, pool);

    uint256 maxWithdraw = pool.maxWithdraw(e);
    uint256 assetsBefore = pool.assetBalance(e);
    uint256 targetAssets = plan.getTargetAssets(e, assetsBefore);

    require(vat.live() == 0);
    require(end.tag(ilk) == RAY());
    require(inkBefore >= artBefore);
    require(assetsBefore >= inkBefore);

    uint256 vatGemEndBeforeOriginal = vat.gem(ilk, end);
    require(inkBefore == 0 || vatGemEndBeforeOriginal == 0); // To ensure correct behavior
    uint256 vatGemEndBefore = vatGemEndBeforeOriginal != 0 ? vatGemEndBeforeOriginal : artBefore;
    uint256 vatDaiVowBefore = vat.dai(vow);

    require(assetsBefore >= vatGemEndBefore);

    exec(e, ilk);

    uint256 LineAfter = vat.Line();
    uint256 debtAfter = vat.debt();
    uint256 ArtAfter;
    uint256 rateAfter;
    uint256 spotAfter;
    uint256 lineAfter;
    uint256 dustAfter;
    ArtAfter, rateAfter, spotAfter, lineAfter, dustAfter = vat.ilks(ilk);
    uint256 inkAfter;
    uint256 artAfter;
    inkAfter, artAfter = vat.urns(ilk, pool);

    uint256 assetsAfter = pool.assetBalance(e);

    uint256 vatGemEndAfter = vat.gem(ilk, end);
    uint256 vatDaiVowAfter = vat.dai(vow);

    // General asserts
    assert(LineAfter == LineBefore, "Line should not change");
    assert(lineAfter == lineBefore, "line should not change");
    assert(artAfter == 0, "art should end up being 0");

    assert(assetsAfter == 0 || assetsAfter == assetsBefore - maxWithdraw, "assets should be 0 or decreased by maxWithdraw");
    assert(vatGemEndAfter == 0 || vatGemEndAfter == vatGemEndBefore - maxWithdraw, "vatGemEnd should be 0 or decreased by maxWithdraw");
    assert(vatDaiVowAfter == vatDaiVowBefore + (assetsBefore - assetsAfter) * RAY(), "vatDaiVow did not increase as expected");
}

rule exec_vat_caged_revert(bytes32 ilk) {
    env e;

    address vow = vow();

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(end() == end);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(vow != daiJoin);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(end.vat() == vat);
    require(end.vow() == vow);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 locked = locked();
    uint256 Art;
    uint256 rate;
    uint256 spot;
    uint256 line;
    uint256 dust;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    uint256 ink;
    uint256 art;
    ink, art = vat.urns(ilk, pool);
    require(Art >= art);
    uint256 endDebt = end.debt();
    uint256 culled = culled(ilk);

    uint256 maxWithdraw = pool.maxWithdraw(e);
    uint256 assets = pool.assetBalance(e);

    require(vat.live() == 0);
    uint256 tag = end.tag(ilk);
    require(tag == RAY());
    require(ink >= art);
    require(assets >= ink);

    uint256 vatWardEnd = vat.wards(end);
    uint256 gap = end.gap(ilk);
    uint256 owe   = art * rate / RAY() * tag / RAY();
    uint256 wad   = ink < owe ? ink : owe;
    uint256 vatGemEnd = vat.gem(ilk, end);
    require(ink == 0 || vatGemEnd == 0); // To ensure correct behavior
    uint256 vatSinVow = vat.sin(vow);
    uint256 vatVice = vat.vice();
    uint256 toSlip = vatGemEnd < maxWithdraw ? vatGemEnd : maxWithdraw;
    uint256 vatWardHub = vat.wards(currentContract);
    uint256 shareBalPool = share.balanceOf(pool);
    uint256 shareSupply = share.totalSupply();
    require(shareSupply >= shareBalPool); // To ensure correct behaviour
    uint256 daiBalShare = dai.balanceOf(share);
    uint256 daiSupply = dai.totalSupply();
    require(daiSupply >= daiBalShare); // To ensure correct behaviour
    uint256 daiAllowanceSharePool = dai.allowance(share, pool);
    uint256 daiBalHub = dai.balanceOf(currentContract);
    uint256 vatDaiDaiJoin = vat.dai(daiJoin);
    uint256 daiAllowanceHubDaiJoin = dai.allowance(currentContract, daiJoin);
    uint256 vatDaiHub = vat.dai(currentContract);
    uint256 vatDaiVow = vat.dai(vow);

    exec@withrevert(e, ilk);

    bool revert1  = e.msg.value > 0;
    bool revert2  = locked != 0;
    bool revert3  = rate != RAY();
    bool revert4  = spot != RAY();
    bool revert5  = endDebt != 0;
    bool revert6  = culled != 0;
    bool revert7  = art * rate > max_uint256;
    bool revert8  = art * tag > max_uint256;
    bool revert9  = gap + (owe - wad) > max_uint256;
    bool revert10 = wad > max_int256() + 1;
    bool revert11 = art > max_int256() + 1;
    bool revert12 = vatWardEnd != 1;
    bool revert13 = to_mathint(rate) * -1 * to_mathint(art) < min_int256();
    bool revert14 = vatGemEnd + wad > max_uint256;
    bool revert15 = vatSinVow + art * RAY() > max_uint256;
    bool revert16 = vatVice + art * RAY() > max_uint256;
    bool revert17 = maxWithdraw > 0 && toSlip > max_int256();
    bool revert18 = maxWithdraw > 0 && vatWardHub != 1;
    bool revert19 = maxWithdraw > 0 && shareBalPool < maxWithdraw;
    bool revert20 = maxWithdraw > 0 && daiBalShare < maxWithdraw;
    bool revert21 = maxWithdraw > 0 && daiAllowanceSharePool < maxWithdraw;
    bool revert22 = maxWithdraw > 0 && daiBalHub + maxWithdraw > max_uint256;
    bool revert23 = maxWithdraw > 0 && maxWithdraw * RAY() > max_uint256;
    bool revert24 = maxWithdraw > 0 && vatDaiDaiJoin < maxWithdraw * RAY();
    bool revert25 = maxWithdraw > 0 && daiAllowanceHubDaiJoin < maxWithdraw;
    bool revert26 = maxWithdraw > 0 && vatDaiHub + maxWithdraw * RAY() > max_uint256;
    bool revert27 = maxWithdraw > 0 && vatDaiVow + maxWithdraw * RAY() > max_uint256;

    assert(revert1  => lastReverted, "revert1 failed");
    assert(revert2  => lastReverted, "revert2 failed");
    assert(revert3  => lastReverted, "revert3 failed");
    assert(revert4  => lastReverted, "revert4 failed");
    assert(revert5  => lastReverted, "revert5 failed");
    assert(revert6  => lastReverted, "revert6 failed");
    assert(revert7  => lastReverted, "revert7 failed");
    assert(revert8  => lastReverted, "revert8 failed");
    assert(revert9  => lastReverted, "revert9 failed");
    assert(revert10 => lastReverted, "revert10 failed");
    assert(revert11 => lastReverted, "revert11 failed");
    assert(revert12 => lastReverted, "revert12 failed");
    assert(revert13 => lastReverted, "revert13 failed");
    assert(revert14 => lastReverted, "revert14 failed");
    assert(revert15 => lastReverted, "revert15 failed");
    assert(revert16 => lastReverted, "revert16 failed");
    assert(revert17 => lastReverted, "revert17 failed");
    assert(revert18 => lastReverted, "revert18 failed");
    assert(revert19 => lastReverted, "revert19 failed");
    assert(revert20 => lastReverted, "revert20 failed");
    assert(revert21 => lastReverted, "revert21 failed");
    assert(revert22 => lastReverted, "revert22 failed");
    assert(revert23 => lastReverted, "revert23 failed");
    assert(revert24 => lastReverted, "revert24 failed");
    assert(revert25 => lastReverted, "revert25 failed");
    assert(revert26 => lastReverted, "revert26 failed");
    assert(revert27 => lastReverted, "revert27 failed");

    assert(lastReverted => revert1  || revert2  || revert3  ||
                           revert4  || revert5  || revert6  ||
                           revert7  || revert8  || revert9  ||
                           revert10 || revert11 || revert12 ||
                           revert13 || revert14 || revert15 ||
                           revert16 || revert17 || revert18 ||
                           revert19 || revert20 || revert21 ||
                           revert22 || revert23 || revert24 ||
                           revert25 || revert26 || revert27, "Revert rules are not covering all the cases");
}

rule exec_exec(bytes32 ilk) {
    env e;

    require(vat() == vat);
    require(daiJoin() == daiJoin);
    require(plan(ilk) == plan);
    require(pool(ilk) == pool);
    require(daiJoin.dai() == dai);
    require(daiJoin.vat() == vat);
    require(plan.dai() == dai);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.dai() == dai);

    uint256 maxDeposit = pool.maxDeposit(e);
    uint256 assetsBefore = pool.assetBalance(e);
    uint256 targetAssets = plan.getTargetAssets(e, assetsBefore);

    require(maxDeposit > targetAssets - assetsBefore);
    require(assetsBefore <= safe_max());

    exec(e, ilk);

    uint256 assetsAfter1 = pool.assetBalance(e);

    uint256 inkAfter1;
    uint256 artAfter1;
    inkAfter1, artAfter1 = vat.urns(ilk, pool);

    exec(e, ilk);

    uint256 assetsAfter2 = pool.assetBalance(e);

    uint256 inkAfter2;
    uint256 artAfter2;
    inkAfter2, artAfter2 = vat.urns(ilk, pool);

    assert(assetsAfter2 == assetsAfter1, "assetsAfter did not remain as expected");
    assert(inkAfter2 == inkAfter1, "inkAfter did not remain as expected");
    assert(artAfter2 == artAfter1, "artAfter did not remain as expected");
}

rule exit(bytes32 ilk, address usr, uint256 wad) {
    env e;

    require(vat() == vat);
    require(pool(ilk) == pool);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.share() == share);

    uint256 vatGemSenderBefore = vat.gem(ilk, e.msg.sender);
    uint256 poolShareUsrBefore = share.balanceOf(usr);

    exit(e, ilk, usr, wad);

    uint256 vatGemSenderAfter = vat.gem(ilk, e.msg.sender);
    uint256 poolShareUsrAfter = share.balanceOf(usr);

    assert(vatGemSenderAfter == vatGemSenderBefore - wad, "vatGemSender did not decrease by wad amount");
    assert(usr != pool => poolShareUsrAfter == poolShareUsrBefore + wad, "poolShareUsr did not increase by wad amount");
}

rule exit_revert(bytes32 ilk, address usr, uint256 wad) {
    env e;

    require(vat() == vat);
    require(pool(ilk) == pool);
    require(pool.hub() == currentContract);
    require(pool.vat() == vat);
    require(pool.share() == share);

    uint256 locked = locked();
    uint256 gem = vat.gem(ilk, e.msg.sender);
    uint256 vatWard = vat.wards(currentContract);
    uint256 balPool = share.balanceOf(pool);
    uint256 balUsr = share.balanceOf(usr);

    exit@withrevert(e, ilk, usr, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = locked != 0;
    bool revert3 = wad > max_int256();
    bool revert4 = vatWard != 1;
    bool revert5 = gem < wad;
    bool revert6 = balPool < wad;
    bool revert7 = pool != usr && balUsr + wad > max_uint256;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");
    assert(revert5 => lastReverted, "revert5 failed");
    assert(revert6 => lastReverted, "revert6 failed");
    assert(revert7 => lastReverted, "revert7 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5 || revert6 ||
                           revert7, "Revert rules are not covering all the cases");
}

rule cage(bytes32 ilk) {
    env e;

    require(vat() == vat);

    cage(e, ilk);

    assert(tic(ilk) == e.block.timestamp + tau(ilk), "tic was not set as expected");
}

rule cage_revert(bytes32 ilk) {
    env e;

    uint256 ward = wards(e.msg.sender);
    uint256 vatLive = vat.live();
    uint256 tic = tic(ilk);
    uint256 tau = tau(ilk);

    cage@withrevert(e, ilk);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = vatLive != 1;
    bool revert4 = tic != 0;
    bool revert5 = e.block.timestamp + tau > max_uint256;

    assert(revert1 => lastReverted, "revert1 failed");
    assert(revert2 => lastReverted, "revert2 failed");
    assert(revert3 => lastReverted, "revert3 failed");
    assert(revert4 => lastReverted, "revert4 failed");
    assert(revert5 => lastReverted, "revert5 failed");

    assert(lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5, "Revert rules are not covering all the cases");
}

rule cull(bytes32 ilk) {
    env e;

    require(vat() == vat);

    uint256 ArtBefore;
    uint256 rateBefore;
    uint256 spotBefore;
    uint256 lineBefore;
    uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = vat.ilks(ilk);

    require(rateBefore == RAY());

    uint256 inkBefore;
    uint256 artBefore;
    inkBefore, artBefore = vat.urns(ilk, pool(ilk));

    uint256 vatGemPoolBefore = vat.gem(ilk, pool(ilk));
    uint256 vatSinVowBefore = vat.sin(vow());
    uint256 vatViceBefore = vat.vice();

    cull(e, ilk);

    uint256 inkAfter;
    uint256 artAfter;
    inkAfter, artAfter = vat.urns(ilk, pool(ilk));

    uint256 vatGemPoolAfter = vat.gem(ilk, pool(ilk));

    uint256 culledAfter = culled(ilk);
    uint256 vatSinVowAfter = vat.sin(vow());
    uint256 vatViceAfter = vat.vice();

    assert(inkAfter == 0, "ink did not go to 0 as expected");
    assert(artAfter == 0, "art did not go to 0 as expected");
    assert(vatGemPoolAfter == vatGemPoolBefore + inkBefore, "vatGemPool did not increase as expected");
    assert(culledAfter == 1, "culled was not set to 1 as expected");
    assert(vatSinVowAfter == vatSinVowBefore + artBefore * RAY(), "vatSinVow did not increase as expected");
    assert(vatViceAfter == vatViceBefore + artBefore * RAY(), "vatVice did not increase as expected");
}

rule cull_revert(bytes32 ilk) {
    env e;

    uint256 vatLive = vat.live();
    uint256 tic = tic(ilk);
    uint256 ward = wards(e.msg.sender);
    uint256 culled = culled(ilk);
    uint256 ink;
    uint256 art;
    ink, art = vat.urns(ilk, pool(ilk));
    uint256 vatWard = vat.wards(currentContract);
    uint256 Art;
    uint256 rate;
    uint256 spot;
    uint256 line;
    uint256 dust;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    require(Art >= art);
    require(rate == RAY());
    uint256 vatGemPool = vat.gem(ilk, pool(ilk));
    uint256 vatSinVow = vat.sin(vow());
    uint256 vatVice = vat.vice();

    cull@withrevert(e, ilk);

    bool revert1  = e.msg.value > 0;
    bool revert2  = vatLive != 1;
    bool revert3  = tic == 0;
    bool revert4  = tic > e.block.timestamp && ward != 1;
    bool revert5  = culled != 0;
    bool revert6  = ink > max_int256();
    bool revert7  = art > max_int256();
    bool revert8  = vatWard != 1;
    bool revert9  = to_mathint(rate) * -1 * to_mathint(art) < min_int256();
    bool revert10 = vatGemPool + ink > max_uint256;
    bool revert11 = vatSinVow + art * RAY() > max_uint256;
    bool revert12 = vatVice + art * RAY() > max_uint256;

    assert(revert1  => lastReverted, "revert1 failed");
    assert(revert2  => lastReverted, "revert2 failed");
    assert(revert3  => lastReverted, "revert3 failed");
    assert(revert4  => lastReverted, "revert4 failed");
    assert(revert5  => lastReverted, "revert5 failed");
    assert(revert6  => lastReverted, "revert6 failed");
    assert(revert7  => lastReverted, "revert7 failed");
    assert(revert8  => lastReverted, "revert8 failed");
    assert(revert9  => lastReverted, "revert9 failed");
    assert(revert10 => lastReverted, "revert10 failed");
    assert(revert11 => lastReverted, "revert11 failed");
    assert(revert12 => lastReverted, "revert12 failed");

    assert(lastReverted => revert1  || revert2  || revert3 ||
                           revert4  || revert5  || revert6 ||
                           revert7  || revert8  || revert9 ||
                           revert10 || revert11 || revert12, "Revert rules are not covering all the cases");
}

rule uncull(bytes32 ilk) {
    env e;

    require(vat() == vat);

    uint256 ArtBefore;
    uint256 rateBefore;
    uint256 spotBefore;
    uint256 lineBefore;
    uint256 dustBefore;
    ArtBefore, rateBefore, spotBefore, lineBefore, dustBefore = vat.ilks(ilk);

    require(rateBefore == RAY());

    uint256 inkBefore;
    uint256 artBefore;
    inkBefore, artBefore = vat.urns(ilk, pool(ilk));

    uint256 vatGemPoolBefore = vat.gem(ilk, pool(ilk));
    uint256 vatDaiVowBefore = vat.dai(vow());

    uncull(e, ilk);

    uint256 inkAfter;
    uint256 artAfter;
    inkAfter, artAfter = vat.urns(ilk, pool(ilk));

    uint256 vatGemPoolAfter = vat.gem(ilk, pool(ilk));

    uint256 culledAfter = culled(ilk);
    uint256 vatDaiVowAfter = vat.dai(vow());

    assert(inkAfter == inkBefore + vatGemPoolBefore, "ink did not increase by prev value of vatGemPool as expected");
    assert(artAfter == artBefore + vatGemPoolBefore, "art did not increase by prev value of vatGemPool as expected");
    assert(vatGemPoolAfter == 0, "vatGemPool did not descrease to 0 as expected");
    assert(culledAfter == 0, "culled was not set to 0 as expected");
    assert(vatDaiVowAfter == vatDaiVowBefore + vatGemPoolBefore * RAY(), "vatDaiVow did not increase as expected");
}

rule uncull_revert(bytes32 ilk) {
    env e;

    uint256 culled = culled(ilk);
    uint256 vatLive = vat.live();
    uint256 vatGemPool = vat.gem(ilk, pool(ilk));
    uint256 vatWard = vat.wards(currentContract);
    uint256 vatSinVow = vat.sin(vow());
    uint256 vatDaiVow = vat.dai(vow());
    uint256 vatVice = vat.vice();
    uint256 vatDebt = vat.debt();
    uint256 Art;
    uint256 rate;
    uint256 spot;
    uint256 line;
    uint256 dust;
    Art, rate, spot, line, dust = vat.ilks(ilk);
    require(rate == RAY());
    uint256 ink;
    uint256 art;
    ink, art = vat.urns(ilk, pool(ilk));

    uncull@withrevert(e, ilk);

    bool revert1  = e.msg.value > 0;
    bool revert2  = culled != 1;
    bool revert3  = vatLive != 0;
    bool revert4  = vatWard != 1;
    bool revert5  = vatSinVow + vatGemPool * RAY() > max_uint256;
    bool revert6  = vatDaiVow + vatGemPool * RAY() > max_uint256;
    bool revert7  = vatVice + vatGemPool * RAY() > max_uint256;
    bool revert8  = vatDebt + vatGemPool * RAY() > max_uint256;
    bool revert9  = ink + vatGemPool > max_uint256;
    bool revert10 = art + vatGemPool > max_uint256;
    bool revert11 = Art + vatGemPool > max_uint256;
    bool revert12 = rate * vatGemPool > max_int256();

    assert(revert1  => lastReverted, "revert1 failed");
    assert(revert2  => lastReverted, "revert2 failed");
    assert(revert3  => lastReverted, "revert3 failed");
    assert(revert4  => lastReverted, "revert4 failed");
    assert(revert5  => lastReverted, "revert5 failed");
    assert(revert6  => lastReverted, "revert6 failed");
    assert(revert7  => lastReverted, "revert7 failed");
    assert(revert8  => lastReverted, "revert8 failed");
    assert(revert9  => lastReverted, "revert9 failed");
    assert(revert10 => lastReverted, "revert10 failed");
    assert(revert11 => lastReverted, "revert11 failed");
    assert(revert12 => lastReverted, "revert12 failed");

    assert(lastReverted => revert1  || revert2  || revert3  ||
                           revert4  || revert5  || revert6  ||
                           revert7  || revert8  || revert9  ||
                           revert10 || revert11 || revert12, "Revert rules are not covering all the cases");
}
