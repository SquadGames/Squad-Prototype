// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Curve.sol";
import "./BondToken.sol";
import "./FeeLib.sol";
import "@nomiclabs/buidler/console.sol";

contract AutoBond is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint16;

    /*
     *  State
     */

    // basis points
    uint16 public networkFeeBasisPoints;

    // address where network fees are sents
    address public treasury;

    // accounts hold funds that may be withdrawn 
    mapping(address => uint256) public accounts;
    uint256 accountsTotal;

    // ERC20 token backing the bonds
    ERC20 public reserveToken;

    Curve public curve;

    // TODO add licenseAgreementURI to bond struct. It's the agreement
    // that the contributor (and copywrite holder) is offering
    struct Bond {
        // beneficiary may claim the surplus for this bond
        address beneficiary;
        // basis points taken out of every sale as surplus for the
        // beneficiary
        uint16 beneficiaryBasisPoints;
        // purchasePrice is emitted in the purchase event so clients can
        // check whether how much a user needs to have for a calid
        // purchase

        uint256 purchasePrice;
        BondToken token;

        string uri;
    }

    // mapping from definition ID to it's bond
    mapping(bytes32 => Bond) public bonds;

    /*
     *  Methods
     */

    constructor(
        uint16 _networkFeeBasisPoints,
        address _reserveToken,
        address _curve,
        address _treasury
    ) public {
        require(
            _networkFeeBasisPoints <= 10000,
            "AutoBond: Network fee greater than 100%"
        );
        require(
            _reserveToken != address(0),
            "Reserve Token ERC20 address required"
        );
        require(_curve != address(0), "Curve address required");
        require(_treasury != address(0), "Treasury address required");
        networkFeeBasisPoints = _networkFeeBasisPoints;
        emit NetworkFeeBasisPointsChange(0, networkFeeBasisPoints);
        reserveToken = ERC20(_reserveToken);
        curve = Curve(_curve);
        treasury = _treasury;
    }

    /*
     *  Admin
     */

    // GlobalFeeBasisPointsChange is emitted when the fee rate changes
    event NetworkFeeBasisPointsChange(uint16 from, uint16 to);

    // setNetworkFeeBasisPoints allows the owner to change the network fee rate
    function setNetworkFeeBasisPoints(uint16 from, uint16 to) public onlyOwner {
        require(networkFeeBasisPoints == from, "fromBasisPoints mismatch");
        require(to <= 10000, "AutoBond: toBasisPoints greater than 100%");
        networkFeeBasisPoints = to;
        emit NetworkFeeBasisPointsChange(from, to);
    }

    // withdraw transfers all owed fees to the network owner and all
    // owed royalties to msg.sender
    function withdraw() public {
        withdrawFor(msg.sender);
    }

    function withdrawFor(address beneficiary) public {
        require(beneficiary != address(0), "beneficiary address required");
        require(accounts[beneficiary] > 0, "Nothing to withdraw");

        // calculate the network fee
        uint256 networkFee;
        uint256 beneficiaryTotal;
        uint256 dust;
        (networkFee, beneficiaryTotal, dust) = FeeLib.calculateFeeSplit(
            networkFeeBasisPoints,
            accounts[beneficiary]
        );
        beneficiaryTotal = beneficiaryTotal.add(dust);

        // transfer the account total minus the network fee to the beneficiary
        require(reserveToken.transfer(beneficiary, beneficiaryTotal));
        accounts[beneficiary] = accounts[beneficiary].sub(
            beneficiaryTotal.add(networkFee)
        );
        accountsTotal = accountsTotal.sub(beneficiaryTotal.add(networkFee));

        // transfer the fee to the treasury
        require(reserveToken.transfer(treasury, networkFee));
    }

    // NewBond is emitted when a new bond is created. The submitter may
    // add arbitrary metadata for clients to build catalogs from
    event NewBond(
        bytes32 bondId,
        address beneficiary,
        uint16 beneficiaryBasisPoints,
        uint256 purchasePrice,
        string metadata,
        string uri
    );

    function createBond(
        bytes32 bondId,
        address beneficiary,
        uint16 beneficiaryBasisPoints,
        uint256 purchasePrice,
        string memory tokenName,
        string memory tokenSymbol,
        string memory metadata,
        string memory uri
    ) public
    {
        require(
            beneficiary != address(0),
            "AutoBond: Beneficiary address required"
        );
        require(
            beneficiaryBasisPoints <= 10000,
            "AutoBond: beneficiaryBasisPoints greater than 100%"
        );
        require(!exists(bondId), "AutoBond: Bond already exists");

        Bond storage newBond = bonds[bondId];
        newBond.beneficiary = beneficiary;
        newBond.beneficiaryBasisPoints = beneficiaryBasisPoints;
        newBond.purchasePrice = purchasePrice;
        newBond.token = new BondToken(tokenName, tokenSymbol);
        newBond.uri = uri;

        emit NewBond(
            bondId,
            beneficiary,
            beneficiaryBasisPoints,
            purchasePrice,
            metadata,
            uri
        );
    }

    event PurchasePriceSet(uint256 currentPrice, uint256 newPrice);

    function setPurchasePrice(
        bytes32 bondId,
        uint256 currentPrice,
        uint256 newPrice
    ) public {
        require(
            bonds[bondId].beneficiary == msg.sender,
            "AutoBond: only the beneficiary can set a purchase price"
        );
        require(
            bonds[bondId].purchasePrice == currentPrice,
            "AutoBond: currentPrice missmatch"
        );
        bonds[bondId].purchasePrice = newPrice;
        emit PurchasePriceSet(currentPrice, newPrice);
    }

    // Purchase is emitted on all bond purchases, and includes enough
    // informatino for clients to track whether someone owns the
    // license according to the purchasePrice at the time of purchase
    event Purchase(
        bytes32 bondId,
        address purchaser,
        uint256 amountPurchased,
        uint256 amountPaid,
        uint256 purchasePrice
    );

    // mint and buy some amount of some bond
    function buyTokens(
        bytes32 bondId,
        uint256 amount,
        uint256 maxPrice
    ) public {
        // get the total price for the amount
        Bond storage bond = bonds[bondId];
        require(
            bond.beneficiary != address(0),
            "AutoBond: Bond does not exist"
        );
        uint256 totalPrice = curve.price(bond.token.totalSupply(), amount);
        require(totalPrice <= maxPrice, "AutoBond: price higher than maxPrice");
        // Charge the sender totalPrice
        require(
            reserveToken.transferFrom(msg.sender, address(this), totalPrice)
        );

        // add beneficiary fee to the beneficiary's account
        uint256 beneficiaryFee;
        uint256 reserveTotal;
        uint256 dust;
        (beneficiaryFee, reserveTotal, dust) = FeeLib.calculateFeeSplit(
            bond.beneficiaryBasisPoints,
            totalPrice
        );
        accounts[bond.beneficiary] = accounts[bond.beneficiary].add(
            beneficiaryFee.add(dust)
        );
        accountsTotal = accountsTotal.add(beneficiaryFee.add(dust));

        // mint the new supply for the purchaser
        bond.token.mint(msg.sender, amount);

        emit Purchase(
            bondId,
            msg.sender,
            amount,
            totalPrice,
            bond.purchasePrice
        );
    }

    event Sale(bytes32 bondId, uint256 amount);

    function sellTokens(
        bytes32 bondId,
        uint256 amount,
        uint256 minValue
    ) public {
        // sell curve = buy curve scaled down by bond.beneficiaryBasisPoints
        require(exists(bondId), "AutoBond: Bond does not exist");
        require(
            bonds[bondId].token.totalSupply() >= amount,
            "not enough supply"
        );
        require(
            balanceOf(bondId, msg.sender) >= amount,
            "Seller doesn't own enough to sell"
        );

        Bond storage bond = bonds[bondId];
        uint256 subtotalValue = curve.price(
            bond.token.totalSupply().sub(amount),
            amount
        );

        uint256 beneficiaryFee;
        uint256 sellerValue;
        uint256 dust;
        (beneficiaryFee, sellerValue, dust) = FeeLib.calculateFeeSplit(
            bond.beneficiaryBasisPoints,
            subtotalValue
        );
        require(sellerValue >= minValue, "AutoBond: value lower than minValue");
        bond.token.burn(msg.sender, amount);
        require(
            reserveToken.transfer(msg.sender, sellerValue),
            "AutoBond: reserve transfer error"
        );

        emit Sale(bondId, amount);
    }

    function transferBondTokenFrom(
        bytes32 bondId,
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        return bonds[bondId].token.transferFrom(from, to, amount);
    }

    function transferBondToken(
        bytes32 bondId,
        address to,
        uint256 amount
    ) public returns (bool) {
        return transferBondTokenFrom(bondId, msg.sender, to, amount);
    }

    function transferReserveTokenFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(from != address(this), "Illegal transfer from this contract");
        require(to != address(this), "Illegal transfer to this contract");
        return reserveToken.transferFrom(from, to, amount);
    }

    function balanceOf(bytes32 bondId, address owner)
        public
        view
        returns (uint256)
    {
        require(owner != address(0), "AutoBond: invalid owner address");
        require(exists(bondId), "AutoBond: bond does not exist");
        return bonds[bondId].token.balanceOf(owner);
    }

    function balance(bytes32 bondId) public view returns (uint256) {
        return balanceOf(bondId, msg.sender);
    }

    function accountBalanceOf(address beneficiary)
        public
        view
        returns (uint256)
    {
        return accounts[beneficiary];
    }

    function accountBalance() public view returns (uint256) {
        return accountBalanceOf(msg.sender);
    }

    function supplyOf(bytes32 bondId) public view returns (uint256) {
        require(exists(bondId), "AutoBond: bond does not exist");
        return bonds[bondId].token.totalSupply();
    }

    function spotPrice(bytes32 bondId) public view returns (uint256) {
        return tokenPriceOf(bondId, 1);
    }

    function tokenPriceOf(bytes32 bondId, uint256 amount)
        public
        view
        returns (uint256)
    {
        require(exists(bondId), "AutoBond: bond does not exist");
        return curve.price(bonds[bondId].token.totalSupply(), amount);
    }

    function licensePriceOf(bytes32 bondId) public view returns (uint256) {
        require(exists(bondId), "AutoBond: bond does not exist");
        return bonds[bondId].purchasePrice;
    }

    function exists(bytes32 bondId) public view returns (bool) {
        return bonds[bondId].beneficiary != address(0);
    }

    function bondAddress(bytes32 bondId) public view returns (address) {
        return address(bonds[bondId].token);
    }

    function reserveDust() public view returns (uint256) {
        return reserveToken.balanceOf(address(this)).sub(accountsTotal);
    }

    function recoverReserveDust() public {
        reserveToken.transfer(treasury, reserveDust());
    }

    function uri(bytes32 bondId) public view returns (string memory) {
        return bonds[bondId].uri;
    }
}
