// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* 
* @title DSCEngine
* @author Owen Lee
* 
* This system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1peg
* This stableCoin has the properties:
* - Exogenous Collateral
* - Dollar pegged
* - Algorithhmically Stavle

* It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC
*
*
* Our DSC system should always be "overcollaterized". At no point, should the value of all collateral <= the $ backed value of all the DSC.
*
* @notice This contract is the core of the DSC system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing Collateral.

* @notice This contract is very loosely based on the MakerDao DSS(DAI) system.
*/

// Deal with this tommorow

contract DSCEngine is ReentrancyGuard {
    ///////////////
    // Errors //

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();

    ///////////////
    // State Variables //
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    DecentralizedStableCoin private immutable i_dsc;

    ///////////////
    // Events //

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ///////////////
    // Modifiers //

    modifier morethanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }

        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert();
        }
        _;
    }

    ///////////////
    // Functions //

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        // For example ETH/USD, BTC/USD, MKR/USD, etc.

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////
    // External Functions //
    function depositCollateralAndMintDsc() external {}

    /* 
    * Follows CEI pattern
    * @param tokenCollateraladdress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to deposit


    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        morethanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external {}
}
