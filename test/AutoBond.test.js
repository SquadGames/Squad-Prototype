/* global require describe it ethers before */

const { assert } = require('chai')

describe('AutoBond', () => {
  let curve
  let autoBond
  let reserveToken
  let owner

  const networkFeeBasisPoints = 200

  before(async () => {
    [owner] = await Promise.all(
      (await ethers.getSigners()).map(async s => {
        return s.getAddress()
      })
    )

    const SimpleLinearCurve = await ethers.getContractFactory('SimpleLinearCurve')
    const AutoBond = await ethers.getContractFactory('AutoBond')
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
      ['owner', owner, await autoBond.owner()],
      ['network fee', networkFeeBasisPoints, await autoBond.getNetworkFeeBasisPoints()],
      ['curve', curve.address, await autoBond.getCurveAddress()]
    ]
    cases.forEach(([param, expected, actual]) => {
      assert.equal(expected, actual, `expected ${expected} ${param}, got ${actual}`)
    })
  })

  it('Emits an initial network fee change event', async () => {
    assert(false, 'Not Implimented')
  })

  it("Won't deploy with bad constructor parameters", async () => {
    assert(false, 'Not Implimented')
  })

  // Submiting

  // Curating

  // Puchasing
})
