// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./AutoBond.sol";
import "./BondToken.sol";
import "@nomiclabs/buidler/console.sol";

// TODO Change the name to Licence something or other
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
        string memory symbol
    ) public ERC721(name, symbol) {
        require(_autoBond != address(0), "Squad: _autoBond address required");
        autoBond = AutoBond(_autoBond);
        ERC20(autoBond.reserveToken()).approve(_autoBond, 2**256 - 1);
    }

    function renewApproval() public {
        ERC20(autoBond.reserveToken()).approve(address(autoBond), 2**256 - 1);
    }

    event NewLicense(
        uint256 id,
        address owner,
        bytes32 bondId,
        uint256 amount,
        string licenseURI
    );

    function mint(
        bytes32 bondId,
        uint256 purchasePrice,
        uint256 maxPrice,
        uint256 amount, // client needs to calculate the amount that
        // will give a close enough price to the
        // purchase price
        string memory licenseURI // TODO move this out of here
    ) public returns (uint256) {
        require(
            autoBond.exists(bondId),
            "Squad: Can't mint licence for non-existent bond"
        );
        require(
            autoBond.licensePriceOf(bondId) == purchasePrice,
            "Squad: purchasePrice mismatch"
        );
        uint256 price = autoBond.tokenPriceOf(bondId, amount);
        require(price >= purchasePrice, "Squad: amount too low");
        require(price <= maxPrice, "Squad: price higher than maxPrice");

        _tokenIds.increment();
        uint256 newLicenseId = _tokenIds.current();
        _mint(msg.sender, newLicenseId);
        _setTokenURI(newLicenseId, licenseURI);

        // transfer purchasePrice worth of the reserve token from msg
        // sender to Squad
        require(
            autoBond.transferReserveTokenFrom(msg.sender, address(this), price)
        );

        // Spend it on minting new bond tokens
        autoBond.buyTokens(bondId, amount, maxPrice);

        // TODO chance license to be claim
        licenses[newLicenseId] = License({bondId: bondId, claimAmount: amount});

        emit NewLicense(newLicenseId, msg.sender, bondId, amount, licenseURI);

        return newLicenseId;
    }

    function redeem(uint256 licenseId) public {
        License memory license = licenses[licenseId];
        require(license.bondId != bytes32(0), "Squad: Licence not found");
        require(
            ownerOf(licenseId) == msg.sender,
            "Squad: Only owner can redeem a license"
        );

        // TODO consider calling this bondTokenAddress
        ERC20(autoBond.bondAddress(license.bondId)).approve(address(autoBond), 2**256 - 1);

        // transfer all the claimed bond token to the caller
        require(
            autoBond.transferBondToken(
                license.bondId,
                ownerOf(licenseId),
                license.claimAmount
            )
        );

        _burn(licenseId);
    }
}
