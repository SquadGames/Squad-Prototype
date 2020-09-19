// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Curve.sol";

contract Squad is Ownable, ERC721 {
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

    // ERC20 token backing the bonds
    address public reserveToken;

    Curve public curve;

    struct Bond {
        // benefactor may claim the surplus for this bond
        address benefactor;
        // basis points taken out of every sale as surplus for the
        // benefactor
        uint16 benefactorBasisPoints;
        // purchasePrice is emitted in the purchase event so clients can
        // check whether how much a user needs to have for a calid
        // purchase
        uint256 purchasePrice;
        // let these default to 0
        uint256 supply;
        mapping(address => uint256) balances;
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
    ) public ERC721("Squad", "SQD") {
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
        reserveToken = _reserveToken;
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

    function withdrawFor(address benefactor) public {
        require(benefactor != address(0), "benefactor address required");
        require(accounts[benefactor] > 0, "Nothing to withdraw");

        // calculate the network fee
        uint256 networkFee;
        uint256 benefactorTotal;
        (networkFee, benefactorTotal) = _calculateFeeSplit(
            networkFeeBasisPoints,
            accounts[benefactor]
        );

        // transfer the account total minus the network fee to the benefactor
        require(IERC20(reserveToken).transfer(benefactor, benefactorTotal));

        // transfer the fee to the treasury
        require(IERC20(reserveToken).transfer(treasury, networkFee));
    }

    // NewBond is emitted when a new bond is created. The submitter may
    // add arbitrary metadata for clients to build catalogs from
    event NewBond(
        bytes32 bondId,
        address benefactor,
        uint16 benefactorBasisPoints,
        uint256 purchasePrice,
        string metadata
    );

    function createBond(
        bytes32 bondId,
        address benefactor,
        uint16 benefactorBasisPoints,
        uint256 purchasePrice,
        string memory metadata
    ) public {
        require(
            benefactor != address(0),
            "AutoBond: Benefactor address required"
        );
        require(
            benefactorBasisPoints <= 10000,
            "AutoBond: benefactorBasisPoints greater than 100%"
        );

        Bond storage newBond = bonds[bondId];
        require(
            newBond.benefactor == address(0),
            "AutoBond: Bond already exists"
        );
        newBond.benefactor = benefactor;
        newBond.benefactorBasisPoints = benefactorBasisPoints;
        newBond.purchasePrice = purchasePrice;

        emit NewBond(
            bondId,
            benefactor,
            benefactorBasisPoints,
            purchasePrice,
            metadata
        );
    }

    event PurchasePriceSet(uint256 currentPrice, uint256 newPrice);

    function setPurchasePrice(
        bytes32 bondId,
        uint256 currentPrice,
        uint256 newPrice
    ) public {
        require(
            bonds[bondId].benefactor == msg.sender,
            "AutoBond: only the benefactor can set a purchase price"
        );
        require(
            bonds[bondId].purchasePrice == currentPrice,
            "AutoBond: currentPrice missmatch"
        );
        bonds[bondId].purchasePrice = newPrice;
        emit PurchasePriceSet(currentPrice, newPrice);
    }

    function _calculateFeeSplit(uint16 basisPoints, uint256 total)
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 fee;
        uint256 remainder;
        fee = total.mul(basisPoints).div(1000);
        remainder = total - fee;
        return (fee, remainder);
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
    function buyBond(
        bytes32 bondId,
        uint256 amount,
        uint256 maxPrice
    ) public {
        // get the total price for the amount
        Bond storage bond = bonds[bondId];
        require(bond.benefactor != address(0), "AutoBond: Bond does not exist");
        uint256 totalPrice = curve.price(bond.supply, amount);
        require(totalPrice <= maxPrice, "price higher than maxPrice");

        // Charge the sender totalPrice
        require(
            IERC20(reserveToken).transferFrom(
                msg.sender,
                address(this),
                totalPrice
            )
        );

        // add benefactor fee to the benefactor's account
        uint256 benefactorFee;
        uint256 _;
        (benefactorFee, _) = _calculateFeeSplit(
            bond.benefactorBasisPoints,
            amount
        );
        accounts[bond.benefactor] = accounts[bond.benefactor].add(
            benefactorFee
        );

        // mint the new supply for the purchaser
        bond.supply = bond.supply.add(amount);
        bond.balances[msg.sender] = bond.balances[msg.sender].add(amount);

        emit Purchase(
            bondId,
            msg.sender,
            amount,
            totalPrice,
            bond.purchasePrice
        );
    }

    event Sale(bytes32 bondId, uint256 amount);

    function sellBond(
        bytes32 bondId,
        uint256 amount,
        uint256 minValue
    ) public {
        // sell curve = buy curve scaled down by bond.benefactorBasisPoints
        Bond storage bond = bonds[bondId];
        require(bond.benefactor != address(0), "AutoBond: Bond does not exist");
        require(bond.supply >= amount, "not enough supply");
        require(false, "Seller doesn't own enough to sell");
        uint256 subtotalValue = curve.price(
            bond.supply.sub(amount),
            bond.supply
        );

        uint256 _;
        uint256 totalValue;
        (_, totalValue) = _calculateFeeSplit(
            bond.benefactorBasisPoints,
            subtotalValue
        );
        require(totalValue >= minValue, "value lower than minValue");
        bond.supply = bond.supply.sub(amount);
        require(IERC20(reserveToken).transfer(msg.sender, totalValue));

        // burn the amount sold from the sellsers balance
        bond.supply = bond.supply.sub(amount);
        bond.balances[msg.sender] = bond.balances[msg.sender].sub(amount);

        emit Sale(bondId, amount);
    }
}
