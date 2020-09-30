/* global module require */

const ethers = require("ethers")

function asUnits(bigNumber, units) {
  return ethers.utils.formatUnits(bigNumber, units)
}

function asEth(bigNumber) {
  return ethers.utils.formatEther(bigNumber)
}

function bnsqrt(a, precision) {
  precision = precision <= 0 ? 1 : precision
  let x = a
  let root
  while(true) {
    root = a.div(x).add(x).div(2)
    if(root.sub(x).abs().lte(precision)) {
      return root
    }
    x = root
  }
}

// TODO test simpleLinearCurveAmou
function practicalLinearCurveAmount(s, p) {
  // simple linear curve x=y
  // given supply S and price P
  // amount A = 1/2(squrt(8P+(2S+1)^2)-2S-1)
  const precision = 1
  const pMult = ethers.BigNumber.from("10").pow(18).mul(8)
  const a = bnsqrt(
    s.mul(2)
      .add(1)
      .pow(2)
      .add(p.mul(pMult)),
    precision
  ).sub(s.mul(2))
        .sub(1)
        .div(2)
  return a.add(precision)
}

module.exports = {
  practicalLinearCurveAmount,
  bnsqrt,
  asUnits,
  asEth
}
