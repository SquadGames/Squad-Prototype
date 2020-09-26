// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

interface Curve {
    function price(uint256 supply, uint256 amount)
        external
        view
        returns (uint256);
}

contract SimpleLinearCurve is Curve {
    using SafeMath for uint256;

    constructor() public {}

    function price(uint256 supply, uint256 amount)
        public
        override
        view
        returns (uint256)
    {
        // sum of the series from supply + 1 to new supply or (supply + amount)
        // average of the first term and the last term timen the number of terms
        //                supply + 1         supply + amount      amount

        uint256 t1 = supply.add(1); // the first newly minted token
        uint256 ta = supply.add(amount); // the last newly minted token
        uint256 a = amount; // number of tokens in the series

        // the forumula is p = a((t1 + ta)/2)
        // but deviding integers by 2 introduces errors that are then multiplied
        // factor the formula to devide by 2 last

        // ((t1 * a) + (ta * a)) / 2

        return t1.mul(a).add(ta.mul(a)).div(2);
    }
}
