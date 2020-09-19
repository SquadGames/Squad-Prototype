# AutoBond

AutoBond manages creating new curved bonds and selling associated NFT
licences

## Data

`uint16 networkFeeBasisPoints`
`address treasury`
`mapping(address => uint256) public accounts`
`address public reserveToken`
`Curve public curve`
```
struct Bond {
    address benefactor;
    uint16 benefactorBasisPoints;
    uint256 purchasePrice;
    uint256 supply;
    mapping(address => uint256 balances;
}
```
`mapping(bytes32 => Bond) puclic bonds`

## Interface

### Constructor

```
constructor(
    uint16 _networkFeeBasisPoints,
    address _reserveToken,
    address _curve,
    address _treasury
) public
```

* Requires `networkFeeBasisPoints` less than or equal to 100% equivilent.
* Requires all addresses not to be zero

### setNetworkFeeBasisPoints

Sets the number of basis points that the network charges to
benefactors as they withdraw from their account.

`function setNetworkFeeBasisPoints(uint16 from, uint16 to) public onlyOwner`

* Requires `from` to match the current value
* Requires `to` to be less than or equal to 100% equivilent.

### withdraw

Transfer the message senders balance to them and the network fee to
the treasury.

`withdraw() public`

* Requires that the caller has an account greater than zero

### withdrawFor

Transfer to the benefactor their balance and the network fee to the
treasury.

`withdrawFor(address benefactor) public`

* Requires a nonzero benefactor address
* Requires that the benefactor's account is greater than zero

### createBond

Create a new bond. The bondId is intended to uniquely identify the
license that the bond represents

```
function createBond(
    bytes32 bondId,
    address benefactor,
    uint16 benefactorBasisPoints,
    uint256 purchasePrice,
    string memory metadata
) public {
```

* Requires a nonzero benefactor address
* Requires that `benefactorBasisPoints` is less than or equal to 100% equivilent
* Requires that a bond with this ID has not yet been created

### setPurchasePrice

The benefactor may change the purchase price for the licence
associated with their bond

`function setPurchasePrice(bytes32 bondId, uint256 currentPrice, uint256 newPrice) public`

* Only the benefactor can set a new purchase price
* Requires the current purchase price to match `currentPrice`

### getPurchasePrice

Returns the current purchase price for the bond

`function getPurchasePrice(bytes32 bondId) returns (uint256)`

### buyBond

Buys an amount of a bonds token

```
function buyBond(
    bytes32 bondId,
    uint256 amount,
    uint256 maxPrice
) public
```

* Requires bond to exist
* Requires the price for minting the `amount` to be less than `maxPrice`
* Transfers `amount` of the `reserveToken` from the caller

### sellBond

Sells an amount of a bonds token

```
function sellBond(
    bytes32 bondId,
    uint256 amount,
    uint256 minValue
) public {
```

* Requires bond to exist
* Requires the value of the sold `amount` of the bond to be higher
  than minValue

### mintLicense

Mint an NFT that wraps the amount of the associated bond that can be
bought for the license purchase price.

`function mintLicense(uint256 bondId, uint256 purchasePrice)`

* Requires bond to exist
* Requires `purchasePrice` to match the current purchase price for the bond
* Transfers `bond.purchasePrice` of the `reserveToken` from the caller

### returnLicense

Burns an NFT and returns the wrapped bond tokens to the owner

`function returnLicense(bytes32 licenseId) public`

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

### returnAndSell

Returns the license and sells an amount of the bond token

`function returnAndSell(bytes32 licenseId)`

* Sells exactly the amount that was in the license
* Requires licenseId to exist

`function returnAndSell(bytes32 licenseId, amount, minValue)`

* Requires the amount in the license plus the callers bond balance to
  be greater than amount
* Requires the value of the sold `amount` of the bond to be higher
  than minValue
