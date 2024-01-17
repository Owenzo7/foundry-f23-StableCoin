// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

// I shall work tommorow tommorow

contract Deploydsc is Script {
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // continue tommorow tommmorow tommorow

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        dsc = new DecentralizedStableCoin();
        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dscEngine));

        vm.stopBroadcast();
        return (dsc, engine, config);
    }
}
