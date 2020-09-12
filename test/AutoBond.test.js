/* global require describe it ethers before */

const { expect, assert } = require('chai')
const { waffle } = require("@nomiclabs/buidler")
const { deployContract, MockProvider } = waffle

describe('AutoBond', () => {

  let curve
  let AutoBond
  let autoBond
  let reserveToken
  let owner
  let alice

  const networkFeeBasisPoints = 200

  before(async () => {
    [owner, alice] = await ethers.getSigners()

    const SimpleLinearCurve = await ethers.getContractFactory('SimpleLinearCurve')
    AutoBond = await ethers.getContractFactory('AutoBond')
    const ERC20 = await ethers.getContractFactory('ERC20')

    reserveToken = await ERC20.deploy('reserveToken', 'RT')
    curve = await SimpleLinearCurve.deploy()
    await reserveToken.deployed()
    await curve.deployed()
    autoBond = await AutoBond.deploy(
      networkFeeBasisPoints,
      reserveToken.address,
      curve.address
    )
  })

  //  Deploying

  it('handles good constructor parameters correctly', async () => {
    const cases = [
      // param name, expected value, actual value
      ['owner', await owner.getAddress(), await autoBond.owner()],
      ['network fee', networkFeeBasisPoints, await autoBond.getNetworkFeeBasisPoints()],
      ['curve', curve.address, await autoBond.getCurveAddress()]
    ]
    cases.forEach(([param, expected, actual]) => {
      assert.equal(expected, actual, `expected ${expected} ${param}, got ${actual}`)
    })
  })

  it("Won't deploy with bad constructor parameters", async () => {
    // should revert when zero address is passed for the resurve token
    await expect(AutoBond.deploy(
      0,
      ethers.constants.AddressZero, // <-- reserve token
      curve.address,
    )).to.be.revertedWith("Reserve Token ERC20 address required")


    // should revert when zero address is passed for the curve address
    await expect(AutoBond.deploy(
      0,
      reserveToken.address,
      ethers.constants.AddressZero, // <-- curve address
    )).to.be.revertedWith("Curve address required")
  })

  // Administration

  it("Only lets the owner change admin properties", async () => {
    const autoBondAsAlice = autoBond.connect(alice)
    await expect(autoBondAsAlice.setNetworkFeeBasisPoints(
      await autoBond.getNetworkFeeBasisPoints(),
      5040,
    )).to.be.revertedWith("Ownable: caller is not the owner")

    await expect(autoBond.setNetworkFeeBasisPoints(
      await autoBond.getNetworkFeeBasisPoints(),
      5040,
    )).not.to.be.reverted
  })

  // Submiting
  it("Lets Alice make a new bond", async () => {
    assert(false, "Not Implemented")
  })

  it("Gives Alice rights of first purchase", async () => {
    assert(false, "Not Implemented")
  })

  it("Only lets Alice change the purchase price", async () => {
    assert(false, "Not Implemented")
  })

  it("Lets only Alice change the benefactor", async () => {
    assert(false, "Not Implemented")
  })

  // Puchasing
  it("Lets Bob buy the good backed by the bond", async () => {
    assert(false, "Not Implemented")
  })

  it("Lets benefactor and the owner withdraw their surplus share", async () => {
    assert(false, "Not Implemented")
  })

  it("Lets Bob 'refinance' the good", async () => {
    assert(false, "Not Implemented")
  })

  // Curating
  it("Lets Carol curate the bond", async () => {
    assert(false, "Not Implemented")
  })
})
