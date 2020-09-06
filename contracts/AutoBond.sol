// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AutoBond is Ownable {
  using SafeMath for uint256;

  /*
   *  State
   */

  // basis points
  uint256 networkFeeBasisPoints;

  // address where network feees are sents
  address treasury;

  // accounts hold funds that may be withdrawn
  mapping(address => uint256) accounts;

  // ERC20 token backing the bonds
  address reserveToken;

  Curve curve;

  struct Bond {
    uint256 supply;
    mapping(address => uint256) balances;

    // basis points taken out of every sale as surplus for the
    // benefactor
    uint256 surplusBasisPoints;

    // benefactor may claim the surplus for this bond
    address benefactor;

    // purchasePrice is emitted in the purchase event so clients can
    // check whether how much a user needs to have for a calid
    // purchase
    uint256 purchasePrice;
  }

  // mapping from definition ID to it's bond
  mapping(bytes32 => Bond) public bonds;

  /*
   *  Events
   */

  // NewBond is emitted when a new bond is created. The submitter may
  // add arbitrary metadata for clients to build catalogs from
  event NewBond(bytes32 bondId, string metadata);

  // Purchase is emitted on all bond purchases, and includes enough
  // informatino for clients to track whether someone has a valid
  // purchase
  event Purchase(bytes32 bondId, address purchaser, uint256 amountPurchased, uint256 amountPaid, uint256 purchasePrice);

  // GlobalFeeBasisPointsChange is emitted when the fee rate changes
  event GlobalFeeBasisPointsChange(uint256 fromBasisPoints, uint256 toBasisPoints);

  /*
   *  Methods
   */

  constructor(uint256 _networkFeeBasisPoints, address _reserveToken, address _curve) public {
    require(_reserveToken != address(0), "Reserve Token ERC20 address required");
    require(_curve != address(0), "Curve address required");
    networkFeeBasisPoints = _networkFeeBasisPoints;
    emit GlobalFeeBasisPointsChange(0, networkFeeBasisPoints);
    reserveToken = _reserveToken;
    curve = Curve(_curve);
  }

  /*
   *  Getters
   */

  function getNetworkFeeBasisPoints() public view returns (uint256) {
    return networkFeeBasisPoints;
  }

  function getCurveAddress() public view returns (address) {
    return address(curve);
  }

  // setGlobalFeeBasisPoints allows the owner to change the network fee rate
  function setGlobalFeeBasisPoints(uint256 fromBasisPoints, uint256 toBasisPoints) public onlyOwner {
    require(networkFeeBasisPoints == fromBasisPoints, "fromBasisPoints mismatch");
    networkFeeBasisPoints = toBasisPoints;
    emit GlobalFeeBasisPointsChange(fromBasisPoints, toBasisPoints);
  }

  // withdraw transfers all owed fees to the network owner and all
  // owed royalties to msg.sender
  function withdraw(address benefactor) public {
    require(benefactor != address(0), "benefactor address required");
    require(accounts[benefactor] > 0, "Nothing to withdraw");

    // calculate the network fee
    uint256 feeAmount = _basisPointsOf(networkFeeBasisPoints, accounts[benefactor]);

    // transfer the account total minus the network fee to the benefactor
    require(IERC20(reserveToken).transfer(benefactor, accounts[benefactor]));

    // transfer the fee to the treasury
    require(IERC20(reserveToken).transfer(treasury, feeAmount));
  }

  // _basisPointsOf calculates the amount of surplus from basisPoints and amount
  function _basisPointsOf(uint256 basisPoints, uint256 amount) internal pure returns (uint256) {
    return amount.mul(basisPoints).div(1000);
  }

  // mint and buy some amount of some bond
  function buy(bytes32 bondId, uint256 amount, uint256 maxPrice) public {
    // get the total price for the amount
    Bond memory bond = bonds[bondId];
    uint256 totalPrice = curve.price(bond.supply, amount);
    require(totalPrice <= maxPrice, "price higher than maxPrice");
    // Charge the sender totalPrice
    require(IERC20(reserveToken).transferFrom(msg.sender, address(this), totalPrice));
    // add surplus to the benefactor's account
    uint256 benefactorSurplus = _basisPointsOf(bond.surplusBasisPoints, amount);
    accounts[bond.benefactor] = accounts[bond.benefactor].add(benefactorSurplus);
  }

  function sell(bytes32 bondId, uint256 amount, uint256 minValue) public {
    // sell curve = buy curve scaled down by bond.surplusBasisPoints
    Bond memory bond = bonds[bondId];
    require(bond.supply >= amount, "not enough supply");
    uint256 subtotalValue = curve.price(bond.supply.sub(amount), bond.supply);
    // totalValue = subtotal - (subtotal * basisPoints)/1000
    uint256 totalValue = subtotalValue.sub(
      _basisPointsOf(bond.surplusBasisPoints, subtotalValue)
    );
    require(totalValue >= minValue, "value lower than minValue");
    bond.supply = bond.supply.sub(amount);
    require(IERC20(reserveToken).transfer(msg.sender, totalValue));
  }
}

interface Curve {
  function price(uint256 supply, uint256 units) external view returns (uint256);
}

contract SimpleLinearCurve is Curve {
  using SafeMath for uint256;

  constructor () public {}

  function price (uint256 supply, uint256 units) public view override returns (uint256) {
    // sum of the series from supply + 1 to new supply or (supply + units)
    // average of the first term and the last term timen the number of terms
    //                supply + 1         supply + units      units

    uint256 a1 = supply.add(1);      // the first newly minted token
    uint256 an = supply.add(units);  // the last newly minted token
    uint256 n = units;               // number of tokens in the series

    // the forumula is n((a1 + an)/2)
    // but deviding integers by 2 introduces errors that are then multiplied
    // factor the formula to devide by 2 last

    // ((a1 * n) + (a2 * n)) / 2

    return a1.mul(n).add(an.mul(n)).div(2);
  }
}

