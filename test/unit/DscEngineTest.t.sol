// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DscEngineTest is Test {
    DeployDsc deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dsce, config) = new deployer.run();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
    }

    ///////////////////////////////
    /// Price Test //////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;

        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }
}
