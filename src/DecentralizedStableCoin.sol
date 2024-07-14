// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.17;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/* 
* @title DecentralizedStableCoin
* @author Owen Lee
* Collateral: Exogeneous (ETH & BTC)
* Minting: Algorithmic
* Relative stablity: Pegged to USD
*
*
* This is the contract meant to be governed by DScEngine. This contract is just the ERC20 implementation of our stablecoin system
*/

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();



// @audit-ok --> Just naming the StableCoin
    constructor() ERC20("DecentralizedStableCoin", "DSC") {}


    // @audit-ok --> Access control is fine
    // @audit-ok --> Overall function is fine.
    function burn(uint256 _amount) public override onlyOwner {
        // @audit-ok --> checking the amount of stableCoin on user
        uint256 balance = balanceOf(msg.sender);

        // @audit-ok --> Less than zero check valid.
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        // @audit-ok --> less balance check valid.
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }

        // @audit-ok
        // Super means use the burn function from the parent class which is (ERC20Burnable.)
        // Used because the burn function is being overridden.
        super.burn(_amount);
    }

    // @audit-ok --> access control valid.
    // @audit-ok --> function is overally valid.
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        // @audit-ok --> zero address check is valid..
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }

        // @audit-ok --> amount less than zero check valid..
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }

        // @audit-ok --> function choice valid
        _mint(_to, _amount);

        // @audit-ok --> return valid.
        return true;
    }
}
