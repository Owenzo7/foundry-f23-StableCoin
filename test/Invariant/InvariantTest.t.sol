// SPDX-License-Identifier: MIT

//  Have our Invariants aka Properties

// What are out Invariants?

pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Deploydsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract invariantTest is StdInvariant, Test {
    Deploydsc deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    function setUp() external {
        deployer = new Deploydsc();
        dsce = deployer.run();
    }
}
