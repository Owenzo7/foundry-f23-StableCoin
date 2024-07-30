// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../src/libraries/OracleLib.sol";

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

// Focus on tests tommorow, tommmorow for sure

contract DSCEngine is ReentrancyGuard {
    ///////////////
    // Errors //

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__DuplicateTokenAddressFound(address tokenAddress);

    using OracleLib for AggregatorV3Interface;

    //////////////////////
    // State Variables //
    ///////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overCollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means a 10% bonus
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    mapping(address => bool) private seenAddresses;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ///////////////
    // Events //

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

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
        // write-up done --> seems valid
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        // For example ETH/USD, BTC/USD, MKR/USD, etc.
        //  --> Possibility of DOS.
        // Likelihood ---> high
        // Impact --> High
        // Duplicates
        // Looping thru a huge array of token addresses
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        // @audit-ok --> seems valid.
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////
    // External Functions //

    /*
    * @param tokenCollateralAddress: The address of the token to deposit as collateral
    * @param amountCollateral: The amount of Collateral to deposit.
    * @param amountDscToMint: The amount of decentralized stablecoin to mint.
    * @notice this function will deposit your collateral and mint Dsc in one transaction.
    */
    // @audit-ok --> exteranl function seems to be fine.
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /* 
    * Follows CEI pattern
    * @param tokenCollateraladdress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to deposit
    */

    // @audit-ok --> this function is valid.
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        morethanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // @audit-ok --> Update of mapping correct
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        // @audit-ok --> correct emission of event
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // @audit-ok --> transfer of collateral token correct.
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);

        // @audit-ok --> token transfer check valid
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
    * @param tokenCollateralAddress The collateral address to redeem
    * @param amountCollateral The amount of collateral to redeem
    * @param amountDscToBurn The amount of Dsc to burn
    * This function burns Dsc and redeems underlying collateral in one transaction
    */

    // @audit-ok --> function seems okay.
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    // In order to redeem collateral:
    // 1. health factor must be over 1 after collateral pulled
    // @audit-ok --> function seems fine.
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        morethanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
    * @notice follows CEI
    * @param amountDscToMint The amount of decentralized stablecoin to mint
    * @notice they must have more collateral value than the minimum threshold
    */
    // @audit-ok --> this whole function is valid.
    function mintDsc(uint256 amountDscToMint) public morethanZero(amountDscToMint) nonReentrant {
        // Check if the collateral value > DSC amount. e.g priceFeeds, value
        // @audit-ok --> tracking of DSC minted valid.
        s_DSCMinted[msg.sender] += amountDscToMint;
        // If the minted too much (e.g $150 DSC, $100 Eth)
        // @audit-ok --> makes sense.
        _revertIfHealthFactorIsBroken(msg.sender);

        // @audit-ok --> minted DSC valid
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        // @audit-ok --> makes sense
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    //  Do we need to check if this breaks health factor
    function burnDsc(uint256 amount) public morethanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // This would never hit
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    //  @audit-ok --> function seems fine.
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        morethanZero(debtToCover)
        nonReentrant
    {
        // @audit-ok --> check health factor valid.
        // Need to check the health factor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);

        // @audit-ok --> health factor check valid.
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        // We want to burn their DSC "debt"
        // And take their collateral
        // Bad User: $140 Eth, $100 DSC
        // debtToCover = $100
        //  $100 of DSC == ??Eth
        uint256 tokenAmountFromDebtCovered = getTokenAmountfromUsd(collateral, debtToCover);

        //  And give them a 10% bonus
        //  So we are giving the liquidator $110 of WETH for 100 DSC
        // We should implement a feature to liquidate in the event the protocol is insolvent.
        // Add sweep extra amounts into a treasury.

        // @audit-ok
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        // @audit-ok --> makes sense
        uint256 totalCollateraltoRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        // @audit-ok
        _redeemCollateral(user, msg.sender, collateral, totalCollateraltoRedeem);
        // @audit-ok
        _burnDsc(debtToCover, user, msg.sender);

        // @audit-ok --> checking health factor seems right valid.
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        // @audit-ok --> seems okay.
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external {}

    ///////////////////////////////////////
    // Private and Internal View Functions //
    /////////////////////////////////////////

    /*
    * @dev Low-level internal function, do not call unless the function calling is
    * Checking for health factors being broken
    *
    */
    // @audit-ok --> function is valid.
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        //  This conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    // @follow-up :: Lack of less than balance check.
    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        // @audit-ok -> state update correct.
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        // @audit-ok --> transfer check valid.
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);

        // @audit-ok --> bool check valid.
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    // @audit-ok --> More of a viewer function.
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];

        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can get liquidated

    */
    // @audit-issue --> Rouding issue.
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    // 1. Check health factor (do they have enough collateral?)
    // 2. Revert if they dont
    // @audit-ok --> function is valid.
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ///////////////////////////////////////
    // Public  and External View Functions //
    /////////////////////////////////////////
    // @follow-up
    function getTokenAmountfromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // Price of ETH (token)
        // $/ETH ETH ??
        //  $ 2000 / ETH $1000 ====> 0.5 ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // ($10e18 * 1e18) / ($2000e8 * 1e10)
        //  =====> 0.005000000000000000
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through each collateral token, get the amount they have deposited and map it to the price, to get the USD value.
        // @audit-issue --> DOS
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        // @follow-up
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // @follow-up
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
