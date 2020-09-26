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

TODO: Add price funtions. Spot price, sell price, buy price for some
amount, market cap

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

Create a new curved bond.

```
function createBond(
    bytes32 bondId,
    address benefactor,
    uint16 benefactorBasisPoints,
    uint256 purchasePrice,
    uint256 initialPurchaseAmount,
    string tokenName,
    string tokenSymbol
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

### buyTokens

Buys an amount of a bonds token

```
function buyTokens(
    bytes32 bondId,
    uint256 amount,
    uint256 maxPrice
) public
```

* Requires bond to exist
* Requires the price for minting the `amount` to be less than `maxPrice`
* Transfers `amount` of the `reserveToken` from the caller

### sellTokens

Sells an amount of a bonds token

```
function sellTokens(
    bytes32 bondId,
    uint256 amount,
    uint256 minValue
) public {
```

* Requires bond to exist
* Requires the value of the sold `amount` of the bond to be higher
  than minValue

### supplyOf

returns the supply of a bond by ID

`function supplyOf(bytes32 bondId) public pure returns (uint256)`

* requires bond to exist

### spotPrice

returns the current price

`function spotPrice(bytes32 bondId) public pure returns(uint256)`

* requires bond to exist

### priceOf

returns the current price of some amount of token

`function priceOf(bytes32 bondID, uint256 amount) public pure returns(uint256)`

* requires bond to exist
