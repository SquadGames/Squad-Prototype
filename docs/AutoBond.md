## `AutoBond`






### `constructor(uint16 _networkFeeBasisPoints, address _reserveToken, address _curve, address _treasury)` (public)





### `setNetworkFeeBasisPoints(uint16 from, uint16 to)` (public)





### `withdraw()` (public)





### `withdrawFor(address beneficiary)` (public)





### `createBond(bytes32 bondId, address beneficiary, uint16 beneficiaryBasisPoints, uint256 purchasePrice, string tokenName, string tokenSymbol, string metadata, string uri)` (public)





### `setPurchasePrice(bytes32 bondId, uint256 currentPrice, uint256 newPrice)` (public)





### `buyTokens(bytes32 bondId, uint256 amount, uint256 maxPrice)` (public)





### `sellTokens(bytes32 bondId, uint256 amount, uint256 minValue)` (public)





### `transferBondTokenFrom(bytes32 bondId, address from, address to, uint256 amount) → bool` (public)





### `transferBondToken(bytes32 bondId, address to, uint256 amount) → bool` (public)





### `transferReserveTokenFrom(address from, address to, uint256 amount) → bool` (public)





### `balanceOf(bytes32 bondId, address owner) → uint256` (public)





### `balance(bytes32 bondId) → uint256` (public)





### `accountBalanceOf(address beneficiary) → uint256` (public)





### `accountBalance() → uint256` (public)





### `supplyOf(bytes32 bondId) → uint256` (public)





### `spotPrice(bytes32 bondId) → uint256` (public)





### `tokenPriceOf(bytes32 bondId, uint256 amount) → uint256` (public)





### `licensePriceOf(bytes32 bondId) → uint256` (public)





### `exists(bytes32 bondId) → bool` (public)





### `bondAddress(bytes32 bondId) → address` (public)





### `reserveDust() → uint256` (public)





### `recoverReserveDust()` (public)





### `uri(bytes32 bondId) → string` (public)






### `NetworkFeeBasisPointsChange(uint16 from, uint16 to)`





### `NewBond(bytes32 bondId, address beneficiary, uint16 beneficiaryBasisPoints, uint256 purchasePrice, string metadata, string uri)`





### `PurchasePriceSet(uint256 currentPrice, uint256 newPrice)`





### `Purchase(bytes32 bondId, address purchaser, uint256 amountPurchased, uint256 amountPaid, uint256 purchasePrice)`





### `Sale(bytes32 bondId, uint256 amount)`





