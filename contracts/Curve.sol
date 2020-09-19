// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

interface Curve {
    function price(uint256 supply, uint256 units)
        external
        view
        returns (uint256);
}

contract SimpleLinearCurve is Curve {
    using SafeMath for uint256;

    constructor() public {}

    function price(uint256 supply, uint256 units)
        public
        override
        view
        returns (uint256)
    {
        // sum of the series from supply + 1 to new supply or (supply + units)
        // average of the first term and the last term timen the number of terms
        //                supply + 1         supply + units      units

        uint256 a1 = supply.add(1); // the first newly minted token
        uint256 an = supply.add(units); // the last newly minted token
        uint256 n = units; // number of tokens in the series

        // the forumula is n((a1 + an)/2)
        // but deviding integers by 2 introduces errors that are then multiplied
        // factor the formula to devide by 2 last

        // ((a1 * n) + (a2 * n)) / 2

        return a1.mul(n).add(an.mul(n)).div(2);
    }
}
