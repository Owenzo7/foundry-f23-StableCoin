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

Limit the maximum allowed length of the tokenAddresses array. 


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
        console.log("This is Duplicate1 Addr::", DUPLICATE2);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert();
        new DSCEngine(tokenAddress, priceFeedAddresses, address(dsc));


    }
```

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