// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

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

contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external {}
}
