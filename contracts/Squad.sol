// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./AutoBond.sol";
import "./BondToken.sol";

contract Squad is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    AutoBond public autoBond;

    struct License {
        bytes32 bondId;
        uint256 claimAmount;
    }

    mapping(uint256 => License) public licenses;

    constructor(
        address _autoBond,
        string memory name,
        string memory ticker
    ) public ERC721(name, ticker) {
        require(_autoBond != address(0), "Squad: _autoBond address required");
        autoBond = AutoBond(_autoBond);
    }

    function mint(
        bytes32 bondId,
        uint256 purchasePrice,
        uint256 maxPrice,
        uint256 amount, // client needs to calculate the amount that
        // will give a close enough price to the
        // purchase price
        string memory licenseURI
    ) public returns (uint256) {
        require(
            autoBond.exists(bondId),
            "Squad: Can't mint licence for non-existent bond"
        );
        require(
            autoBond.purchasePriceOf(bondId) == purchasePrice,
            "Squad: purchasePrice mismatch"
        );
        uint256 price = autoBond.priceOf(bondId, amount);
        require(price >= purchasePrice, "Squad: amount too low");
        require(price <= maxPrice, "Squad: price too high");

        _tokenIds.increment();
        uint256 newLicenseId = _tokenIds.current();
        _mint(msg.sender, newLicenseId);
        _setTokenURI(newLicenseId, licenseURI);

        // transfer purchasePrice worth of the reserve token from msg sender to Squad
        require(
            autoBond.transferBondTokenFrom(
                bondId,
                msg.sender,
                address(this),
                purchasePrice
            )
        );

        // Spend it on minting new bond tokens
        autoBond.buyTokens(bondId, amount, purchasePrice);

        licenses[newLicenseId] = License({
            bondId: bondId,
            claimAmount: amount
        });

        return newLicenseId;
    }

    function redeem(uint256 licenseId) public {
        License memory license = licenses[licenseId];
        require(license.bondId != bytes32(0), "Squad: Licence not found");
        require(
            this.ownerOf(licenseId) == msg.sender,
            "Squad: Only owner can redeem a license"
        );

        delete licenses[licenseId];
    }
}
