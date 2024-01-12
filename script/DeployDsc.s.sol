// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract Deploydsc is Script {
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        vm.startBroadcast();
        dsc = new DecentralizedStableCoin();
        // engine = new DSCEngine();

        vm.stopBroadcast();
    }
}
