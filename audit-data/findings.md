### [H-1] Possibility of a DOS attack when looping through a huge array in the constructor.

**Description:** 
The constructor loops through the `tokenAddresses` array and assigns corresponding priceFeedAddress elements to the `s_priceFeeds` mapping. If the tokenAddresses array is extremely large, this could lead to high gas consumption, potentially causing the transaction to fail or making the contract vulnerable to a Denial of Service (DoS) attack.

```javascript

constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

@>        for (uint256 i = 0; i < tokenAddresses.length; i++) {
@>            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
@>            s_collateralTokens.push(tokenAddresses[i]);
@>        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

```

**Impact:**

If the length of the tokenAddresses array is excessively large, the gas required to execute the constructor could exceed the block gas limit, causing the transaction to fail. This would prevent the contract from being deployed successfully, leading to a DOS attack.

**Proof of Concept:**

1. An attacker can use a substantial amount of tokenAddresses and deploy them in the contract which causes a DOS attack mainly because of the looping through the token addresses to match them with the priceFeed Addresses.

**Recommended Mitigation:** 

Limit the maximum allowed length of the `tokenAddresses` array. 


### [H-2] DOS attack that may occur at `DSCEngine::getAccountCollateralValue` function which may exceed the block gas limit.

**Description:** 

The `DSCEngine::getAccountCollateralValue` function includes a loop that iterates through the `s_collateralTokens` array. If this array contains a large number of collateral tokens, the transaction could exceed the block gas limit and fail.

```javascript
function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {

@>        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
@>            address token = s_collateralTokens[i];
@>            uint256 amount = s_collateralDeposited[user][token];
@>            totalCollateralValueInUsd += getUsdValue(token, amount);
@>        }
@>        return totalCollateralValueInUsd;
@>    }

```

**Impact:** 

This may cause some Collateral tokens in the `s_collateralTokens` array not to be matched with a USD value thus making false records of health factors of unlucky users which may cause some of them to be liquidated unfairly.

**Proof of Concept:**

1. A user adds a collateral token to the unbounded s_collateralTokens array, which may contain numerous collateral tokens.
2. The function DSCEngine::getAccountCollateralValue attempts to match the user's collateral tokens with their USD values.
3. The transaction fails due to exceeding the block gas limit, causing a health factor of 0 to be enforced on the user and leading to unfair liquidation.

**Recommended Mitigation:** 

Limit the maximum length of the s_collateralTokens array to ensure that the transaction does not exceed the block gas limit, allowing all collateral tokens to be matched to their respective USD values.


### [H-3] Users Can Liquidate Themselves to Avoid Some Losses and Collect Liquidator Bonus 

**Description:** 

A user can call the `liquidate` function on themselves if their health factor is below 0 and close their position in the protocol before incurring hefty costs.

**Impact:** 

The user may be able to pay off their debt within the protocol but unfairly earn the liquidator bonus.

**Proof of Concept:**
1. A user's health factor goes below 0, making them eligible for liquidation.
2. The user then calls the liquidate function on themselves, closing their position and collecting the liquidator bonus.

**Recommended Mitigation:** 

Add some checks in the `DSCEngine::liquidate` function, to avoid Users from liquidating themselves.

```diff

+ error DSCEngine__UserCannotLiquidatehimself(address user);

function liquidate(address collateral, address user, uint256 debtToCover)
        external
        morethanZero(debtToCover)
        nonReentrant
    {

+        if(msg.sender == user){
+            revert DSCEngine__UserCannotLiquidatehimself(user);
+        }
        
        
        uint256 startingUserHealthFactor = _healthFactor(user);

       
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateraltoRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateral, totalCollateraltoRedeem);
        
        _burnDsc(debtToCover, user, msg.sender);

        
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

```

With this check, a user is unable to liquidate himself and acquiring the liquidation bonus unfairly.



### [M-1] Potential for Duplicate Token addresses at the constructor when being deployed.

**Description:** 

The constructor does not check for duplicate entries in the `tokenAddresses` array. This can lead to incorrect mapping of `tokenAddresses` to `priceFeedAddress`, which can cause unexpected behavior in the contract.

```javascript
constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
       
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

@>        for (uint256 i = 0; i < tokenAddresses.length; i++) {
@>            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
@>            s_collateralTokens.push(tokenAddresses[i]);
@>        }

      
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

```

**Impact:** 

If duplicate token addresses are present, the later price feed addresses will overwrite the earlier ones in the `s_priceFeeds` mapping. This could result in incorrect price feed data being used for collateral tokens, potentially affecting the stability and reliability of the Decentralized Stable Coin (DSC) system.

**Proof of Concept:**

1. Attacker creates two duplicate token addresses.
2. Attacker deploys the contract with the two duplicate token addresses.

**Proof of Code**
<details>
<summary>Code</summary>

Place the following to the `DscEngineTest.t.sol` test suite.

```javascript
function testRevertsIfConstrutordetectsDuplicateTokenAddresses() public {
        tokenAddress.push(DUPLICATE1);
        tokenAddress.push(DUPLICATE2);

        console.log("This is Duplicate1 Addr::", DUPLICATE1);
        console.log("This is Duplicate2 Addr::", DUPLICATE2);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert();
        new DSCEngine(tokenAddress, priceFeedAddresses, address(dsc));


    }
```

</details>

The code above doesn't revert since there is no duplicate check in the `Dsc` construtor.

**Recommended Mitigation:** 

Add a check to ensure that there are no duplicate entries in the `tokenAddresses` array before proceeding with the loop.

```diff
constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        
       
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

+         // Initialize a mapping to track seen addresses
+        mapping(address => bool) memory seenAddresses;

        for (uint256 i = 0; i < tokenAddresses.length; i++) {

+            // Check for duplicates
+        if (seenAddresses[tokenAddresses[i]]) {
+            revert DSCEngine__DuplicateTokenAddressFound(tokenAddresses[i]);
+        }


+        seenAddresses[tokenAddresses[i]] = true;


            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

       
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

```

By adding this check, you ensure that the `tokenAddresses` array does not contain duplicates, thus maintaining the consistency and integrity of the contract data.


### [L-1] Collateral token sent directly to the dsce contract does not mint a Sc and lacks recovery mechanism.

**Description:** 

A `User` that sends a collateral token directly to the DSCE contract will not receive minted stablecoin nor be able to recover the collateral token sent directly to the contract.

**Impact:** 

This may cause the `User` to lose their collateral tokens within the contract since there is no recovery mechanism present in the contract.

**Proof of Concept:**

<details>
<summary>Code</summary>

Place the following to the `DscEngineTest.t.sol` test suite.

```javascript

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

```

The following is the log of the amount of minted DSC that the user got after the transaction.

```bash

[2582] DSCEngine::getAmountOfDSCminted(user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D]) [staticcall]
    │   └─ ← [Return] 0
    ├─ [0] console::log("This is the amount of Dsc that the User has minted::", 0) [staticcall]
    │   └─ ← [Stop] 

```

</details>

From the transaction carried out by the `USER`, the `USER` did not acquire any minted DSC nor can he recover his collateral token that was sent directly to the contract.

**Recommended Mitigation:**

A recovery mechanism must be implemented within the contract for the lost collateral tokens.


