// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {Deploydsc} from "../../script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DscEngineTest is Test {
    Deploydsc deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address public DUPLICATE1 = address(0x123);
    address public DUPLICATE2 = address(0x123);

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_SELFCOLLATERAL = 3 ether;

    address public USER = makeAddr("user");

    function setUp() public {
        deployer = new Deploydsc();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////////////
    /// Constructor Test //////////

    address[] public tokenAddress;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddress.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddress, priceFeedAddresses, address(dsc));
    }

    function testRevertsIfConstrutordetectsDuplicateTokenAddresses() public {
        tokenAddress.push(DUPLICATE1);
        tokenAddress.push(DUPLICATE2);

        console.log("This is Duplicate1 Addr::", DUPLICATE1);
        console.log("This is Duplicate1 Addr::", DUPLICATE2);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert();
        new DSCEngine(tokenAddress, priceFeedAddresses, address(dsc));
    }

    function testIfWETHsentDirectlyToContractIsGivenAMintedDsc() public {
        // User starts the transaction
        vm.startPrank(USER);
        // User sends his WETH to the Dsc contract directly.
        // STARTING_ERC20_BALANCE ==> 10 ether.
        ERC20Mock(weth).transfer(address(dsc), STARTING_ERC20_BALANCE);
        vm.stopPrank();

        // Displays the amount of Dsc that the User acquired after the tx.
        console.log("This is the amount of Dsc that the User has minted::", dsce.getAmountOfDSCminted(USER));
    }

    function testIfUSERcanLiquidatehimself() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        // User deposits Collateral
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 2e18);
        vm.stopPrank();

        uint256 amountofDScForUser = dsc.balanceOf(USER);

        console.log("This is the amount of DSC that USER has::", amountofDScForUser);

        // User now trys to liquidate himself
        vm.startPrank(USER);
        dsce.liquidate(weth, USER, amountofDScForUser);
        vm.stopPrank();
    }

    // @follow-up
    function testIfdsceEngineContractisDepositingCollateralToItself() public {
        // Mint some WETH(10 ether) to the DSCE engine contract.
        ERC20Mock(weth).mint(address(dsce), STARTING_ERC20_BALANCE);
        ERC20Mock(weth).approve(address(dsce), STARTING_ERC20_BALANCE);

        // Deposit collateral to self
        vm.startPrank(address(dsce));

        dsce.depositCollateral(weth, AMOUNT_SELFCOLLATERAL);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// Price Test //////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;

        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountfromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    ///////////////////////////////
    /// DepositCollateral Test //////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approveInternal(address(dsce), USER, AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);

        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }
}
