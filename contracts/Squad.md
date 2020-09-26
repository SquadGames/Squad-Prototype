# Squad

## Data

`AutoBond public autoBond`

```
struct License {
    bytes32 bondId;
    uint256 wrappedAmount;
    address owner;
}
```

`mapping(uint256 => License) public licenses`

## Interface

### constructor

* needs to take in the autoBond address

### mint

Mint an NFT that claims the amount of the associated bond token that
can be bought for the license purchase price.

`function mint(uint256 bondId, uint256 purchasePrice, uint256 amount, string memory licenseURI)`

* Requires bond to exist
* Requires `purchasePrice` to match the current purchase price for the bond
* Requires price of amount to be greater than purchasePrice
* Requires price of amount to be lsee than maxAmount
* Transfers `bond.purchasePrice` of the `reserveToken` from the caller

### redeem

Burns an NFT and transfers the bond tokens it claimed to the owner

`function redeemLicense(uint256 licenseId) public`

* Requires the license to exist
* Requires the caller to own the license

### buyAndMint

Buys exactly enough (or a specified amount) of the bond and wraps it
in a newly minted License for the caller

`function buyAndMint(bytes32 bondId) public`

* Requires the bond to exist
* Transfers `bond.purchasePrice` of the `reserveToken` from the caller

`function buyAndMint(bytes32 bondId, uint256 amount, maxPrice) public`

* Requires the callers bond balance + amount to be enough to mint a bond
* Requires the price for minting the `amount` to be less than `maxPrice`
* Transfers `amount` of the `reserveToken` from the caller

### redeemAndSell

Redeems the license and sells an amount of the bond token

`function redeemAndSell(bytes32 licenseId)`

* Sells exactly the amount that was in the license
* Requires licenseId to exist

`function redeemAndSell(bytes32 licenseId, amount, minValue)`

* Requires the amount in the license plus the callers bond balance to
  be greater than amount
* Requires the value of the sold `amount` of the bond to be higher
  than minValue
