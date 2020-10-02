/* global require describe it ethers beforeEach */

const { expect, assert } = require('chai')
const { waffle } = require('@nomiclabs/buidler')
const { deployContract, MockProvider } = waffle
const { practicalLinearCurveAmount, asEth } = require('../lib/utils.js')

describe('AutoBond', () => {
  let curve
  let AutoBond
  let autoBond
  let Squad
  let squad
  let reserveToken
  let reserveTokenAsAlice
  let reserveTokenAsBob
  let reserveTokenAsCarol
  let owner
  let alice
  let bob
  let carol
  let treasury
  let ownerWallet
  let aliceWallet
  let bobWallet
  let carolWallet
  let treasuryWallet
  let autoBondAsAlice
  let autoBondAsBob
  let autoBondAsCarol
  let squadAsAlice
  let squadAsBob
  let squadAsCarol

  const networkFeeBasisPoints = 200

  beforeEach(async () => {
    [ownerWallet, treasuryWallet, aliceWallet, bobWallet, carolWallet] = await ethers.getSigners()
    owner = await ownerWallet.getAddress()
    alice = await aliceWallet.getAddress()
    bob = await bobWallet.getAddress()
    carol = await carolWallet.getAddress()
    treasury = await treasuryWallet.getAddress()

    const PracticalLinearCurve = await ethers.getContractFactory('PracticalLinearCurve')
    AutoBond = await ethers.getContractFactory('AutoBond')
    const ReserveToken = await ethers.getContractFactory('BondToken')

    reserveToken = await ReserveToken.deploy('reserveToken', 'RT')
    reserveTokenAsAlice = reserveToken.connect(aliceWallet)
    reserveTokenAsBob = reserveToken.connect(bobWallet)
    reserveTokenAsCarol = reserveToken.connect(carolWallet)
    curve = await PracticalLinearCurve.deploy()
    await reserveToken.deployed()
    await curve.deployed()
    autoBond = await AutoBond.deploy(
      networkFeeBasisPoints,
      reserveToken.address,
      curve.address,
      treasury
    )
    await autoBond.deployed()
    autoBondAsAlice = autoBond.connect(aliceWallet)
    autoBondAsBob = autoBond.connect(bobWallet)
    autoBondAsCarol = autoBond.connect(carolWallet)

    Squad = await ethers.getContractFactory('Squad')
    squad = await Squad.deploy(
      await autoBond.address,
      'TestSquad NFT',
      'TSN'
    )

    squadAsAlice = squad.connect(aliceWallet)
    squadAsBob = squad.connect(bobWallet)
    squadAsCarol = squad.connect(carolWallet)
  })

  //  Deploying

  it('handles good constructor parameters correctly', async () => {
    const cases = [
      // param name, expected value, actual value
      ['owner', owner, await autoBond.owner()],
      ['network fee', networkFeeBasisPoints, await autoBond.networkFeeBasisPoints()],
      ['curve', curve.address, await autoBond.curve()],
      ['treasury', treasury, await autoBond.treasury()]
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
      treasury
    )).to.be.revertedWith('Reserve Token ERC20 address required')

    // should revert when zero address is passed for the curve address
    await expect(AutoBond.deploy(
      0,
      reserveToken.address,
      ethers.constants.AddressZero, // <-- curve address
      treasury
    )).to.be.revertedWith('Curve address required')

    // should revert when zero address is passed for the treasury address
    await expect(AutoBond.deploy(
      0,
      reserveToken.address,
      curve.address,
      ethers.constants.AddressZero // <-- treasury address
    )).to.be.revertedWith('Treasury address required')
  })

  // Administration

  // check that it reverts if the wrong current fee is sent when
  // trying to change the fee

  it('Only lets the owner change admin properties', async () => {
    await expect(autoBondAsAlice.setNetworkFeeBasisPoints(
      await autoBond.networkFeeBasisPoints(),
      5040
    )).to.be.revertedWith('Ownable: caller is not the owner')

    await expect(autoBond.setNetworkFeeBasisPoints(
      await autoBond.networkFeeBasisPoints(),
      5040
    )).not.to.be.reverted
  })

  // Submiting

  it('Lets Alice make and administer a new bond', async () => {
    const bondId = ethers.utils.formatBytes32String('testAliceBondId0')
    const benefactor = alice
    const benefactorBasisPoints = ethers.BigNumber.from('179')
    const purchasePrice = ethers.constants.WeiPerEther.mul('10') // 10 bucks
    const tokenName = 'testAliceTokenName'
    const tokenSymbol = 'TATS'
    const metadata = 'testAliceBondMetaData0'

    await expect(
      autoBondAsAlice.createBond(
        bondId,
        benefactor,
        benefactorBasisPoints,
        purchasePrice,
        tokenName,
        tokenSymbol,
        metadata
      )
    ).to.emit(autoBond, 'NewBond').withArgs(
      bondId,
      benefactor,
      benefactorBasisPoints,
      purchasePrice,
      metadata
    )

    // Alice can set the purchase price on their bond
    const newPurchasePrice = ethers.constants.WeiPerEther.mul(12) // 12 bucks
    await expect(
      autoBondAsAlice.setPurchasePrice(bondId, purchasePrice, newPurchasePrice)
    ).to.emit(autoBond, 'PurchasePriceSet').withArgs(
      purchasePrice, newPurchasePrice
    )

    // Alice needs to assign the correct current purchase price to change it
    const anotherPurchasePrice = ethers.constants.WeiPerEther.mul(5)
    await expect(
      autoBondAsAlice.setPurchasePrice(bondId, purchasePrice, anotherPurchasePrice)
    ).to.be.revertedWith('AutoBond: currentPrice missmatch')

    // Bob cannot set the purchase price on Alice's bond
    const bobsPurchasePrice = ethers.constants.WeiPerEther
    await expect(
      autoBondAsBob.setPurchasePrice(bondId, newPurchasePrice, bobsPurchasePrice)
    ).to.be.revertedWith('AutoBond: only the benefactor can set a purchase price')

    // The bond was set up correctly
    const alicesBond = await autoBondAsCarol.bonds(bondId)
    const alicesAddress = alice
    const cases = [
      ['supply', '0', (await autoBondAsCarol.supplyOf(bondId)).toString()],
      ['benefactor', alicesAddress, alicesBond.benefactor],
      ['benefactorBasisPoints', benefactorBasisPoints.toString(), alicesBond.benefactorBasisPoints.toString()],
      ['purchasePrice', newPurchasePrice.toString(), alicesBond.purchasePrice.toString()]
    ]

    cases.forEach(([property, expected, actual]) => {
      assert(
        expected === actual,
        `expected Bond.${property} to be ${expected} but got ${actual}`)
    })
  })

  it('Rejects new bonds with basis points totalling more than 100%', async () => {
    const bondId = ethers.utils.formatBytes32String('testBobBondId0')
    const benefactor = bob
    const allowedBasisPoints = ethers.BigNumber.from('10000')
    const excessiveBasisPoints = ethers.BigNumber.from('10001')
    const purchasePrice = ethers.constants.WeiPerEther.mul('10') // 10 bucks
    const tokenName = 'BobsToken'
    const tokenSymbol = 'BT'
    const metadata = ethers.utils.formatBytes32String('testBobBondMetaData0')

    await autoBondAsBob.createBond(
      bondId,
      benefactor,
      allowedBasisPoints,
      purchasePrice,
      tokenName,
      tokenSymbol,
      metadata
    )

    await expect(
      autoBondAsBob.createBond(
        bondId,
        benefactor,
        excessiveBasisPoints,
        purchasePrice,
        tokenName,
        tokenSymbol,
        metadata
      )
    ).to.be.revertedWith('AutoBond: benefactorBasisPoints greater than 100%')
  })

  it.skip('Gives Alice rights of first purchase', async () => {
    const bondId = ethers.utils.formatBytes32String('testAliceBondId1')
    const metadata = ethers.utils.formatBytes32String('testAliceBondMetaData1')
    const benefactor = alice
    const basisPoints = ethers.BigNumber.from('100')
    const initialBuyAmount = ethers.constants.WeiPerEther.mul('10')
    const purchasePrice = ethers.constants.WeiPerEther.mul('12') // 12 bucks

    await expect(() => {
      autoBondAsAlice.createBond(
        bondId,
        benefactor,
        basisPoints,
        purchasePrice,
        initialBuyAmount,
        metadata
      )
    }).to.changeBalance(benefactor, -50)

    // Alice should have 100 of the bond's token
    assert(
      await autoBond.balanceOf(bondId, benefactor),
      initialBuyAmount,
      'Initial buy amount mismatch'
    )
  })

  it.skip('Only lets Alice change the purchase price', async () => {
    assert(false, 'Not Implemented')
  })

  it.skip('Lets only Alice change the benefactor', async () => {
    assert(false, 'Not Implemented')
  })

  // Puchasing
  it('Lets Bob mint a license for themself', async () => {
    // Set Up
    const bondId = ethers.utils.formatBytes32String('testAliceBondId0')
    const benefactor = alice
    const benefactorBasisPoints = ethers.BigNumber.from('179')
    const purchasePrice = ethers.constants.WeiPerEther.mul('10') // 10 bucks
    const tokenName = 'testAliceTokenName'
    const tokenSymbol = 'TATS'
    const metadata = 'testAliceBondMetaData0'

    await autoBondAsAlice.createBond(
      bondId,
      benefactor,
      benefactorBasisPoints,
      purchasePrice,
      tokenName,
      tokenSymbol,
      metadata
    )

    const maxPurchasePrice = ethers.constants.WeiPerEther.mul('11')
    const testLicenseUri = `example://metastore/${bondId}`
    const S = await autoBond.supplyOf(bondId)
    const amount = practicalLinearCurveAmount(S, purchasePrice)

    // Bob needs to have enough reserve token to pay the purchase
    // price transfer not quite enough to bob and confirm that it
    // reverts appropriately
    const insufficientAmount = purchasePrice.sub(1)
    reserveToken.mint(bob, insufficientAmount)
    await expect(
      squadAsBob.mint(
        bondId,
        purchasePrice,
        maxPurchasePrice,
        amount,
        testLicenseUri
      )
    ).to.be.revertedWith(
      'ERC20: transfer amount exceeds balance'
    )
    // transfer just enough and watch the error change to reverting
    // because of allowance
    reserveToken.mint(
      bob,
      maxPurchasePrice.sub(purchasePrice).add(1) // puts bob at maxPurchasePrice
    )

    await expect(
      squadAsBob.mint(
        bondId,
        purchasePrice,
        maxPurchasePrice,
        amount,
        testLicenseUri
      )
    ).to.be.revertedWith(
      'ERC20: transfer amount exceeds allowance'
    )

    // set the allowance high enough and watch it succeed
    await reserveTokenAsBob.approve(autoBond.address, maxPurchasePrice)
    await squadAsBob.mint(
      bondId,
      purchasePrice,
      maxPurchasePrice,
      amount,
      testLicenseUri
    )

    return new Promise((resolve, reject) => {
      squad.on('Transfer', async (from, to, tokenId, event) => {
        try {
          // confirm that bob owns the license
          assert(from === ethers.constants.AddressZero, 'Incorrect from address')
          assert(to === bob, 'Not created for Bob')
          assert(await squad.ownerOf(tokenId) === bob, 'Incorrect owner')
          // confirm that the token has the right metadata
          assert(
            await squad.tokenURI(tokenId) === testLicenseUri,
            'tokenURI missmatch'
          )
          // bob should have spent all their reserve token
          const bobReserveBalance = await reserveToken.balanceOf(bob)
          assert(
            bobReserveBalance.lt(ethers.constants.WeiPerEther),
            'Bob reserveToken balance too high'
          )
          // at least purchasePrice of reserve token should held by the bond
          assert(
            (await reserveToken.balanceOf(autoBond.address)).gte(purchasePrice),
            `autoBond should hold at least ${purchasePrice} of the reserve token`
          )
          // `amount` of bond should be held by Squad
          assert(
            (await autoBond.balanceOf(bondId, squad.address)).eq(amount),
            'squad holds wrong amount of bond'
          )
          resolve()
        } catch (e) {
          reject(e)
        }
      })
    })
  })

  it('Lets benefactor withdraw their share and pay network fees', async () => {
    // set up

    // Alice makes a bond with benefactor basis points
    const bondId = ethers.utils.formatBytes32String('testAliceBondId0')
    const benefactor = alice
    const benefactorBasisPoints = ethers.BigNumber.from('100')
    const purchasePrice = ethers.constants.WeiPerEther.mul('10') // 20 bucks
    const tokenName = 'testAliceTokenName'
    const tokenSymbol = 'TATS'
    const metadata = 'testAliceBondMetaData0'

    await autoBondAsAlice.createBond(
      bondId,
      benefactor,
      benefactorBasisPoints,
      purchasePrice,
      tokenName,
      tokenSymbol,
      metadata
    )

    // people buy some
    const maxPurchasePrice = ethers.constants.WeiPerEther.mul('11')
    const testLicenseUri = `example://metastore/${bondId}`
    let supply = await autoBond.supplyOf(bondId)
    let amount = practicalLinearCurveAmount(supply, purchasePrice)

    // Bob and Carol each buy 5 licenses for > 10 bucks
    reserveToken.mint(bob, maxPurchasePrice.mul(5))
    reserveTokenAsBob.approve(autoBond.address, maxPurchasePrice.mul(5))
    reserveToken.mint(carol, maxPurchasePrice.mul(5))
    reserveTokenAsCarol.approve(autoBond.address, maxPurchasePrice.mul(5))
    let totalAmount = 0
    for (let i = 0; i < 5; i++) {
      supply = await autoBond.supplyOf(bondId)
      amount = practicalLinearCurveAmount(supply, purchasePrice)
      totalAmount = amount.add(totalAmount)
      await squadAsBob.mint(
        bondId,
        purchasePrice,
        maxPurchasePrice,
        amount,
        testLicenseUri
      )
      supply = await autoBond.supplyOf(bondId)
      amount = practicalLinearCurveAmount(supply, purchasePrice)
      totalAmount = amount.add(totalAmount)
      await squadAsCarol.mint(
        bondId,
        purchasePrice,
        maxPurchasePrice,
        amount,
        testLicenseUri
      )
    }

    // There should be > 100 bucks in AutoBond
    const autoBondBalance = await reserveToken.balanceOf(autoBond.address)
    assert(
      autoBondBalance.gt(ethers.constants.WeiPerEther.mul(100)),
      'Incorrect autoBond reserve token balance'
    )
    // Alice can withdraw her share which should be 1 - 0.02 with a
    // 200 basis points network fee
    // Alice and the treasury starts with zero reserve token
    assert(
      (await reserveToken.balanceOf(alice)).eq(0),
      'Incorrect Alice starting reserve balance'
    )
    assert(
      (await reserveToken.balanceOf(treasury)).eq(0),
      'Incorrect treasury starting reserve balance'
    )

    // Execute System under test
    autoBondAsAlice.withdraw()

    // Alice should have 0.98 reserve token or a little more after withdrawing
    const aliceBalance = await reserveToken.balanceOf(alice)
    assert(
      aliceBalance.gte(ethers.utils.parseEther('0.98')),
      'Incorrect Alice balance after withdraw'
    )

    // The treasury gets it's shair wich should be .02
    const treasuryBalance = await reserveToken.balanceOf(treasury)
    assert(
      treasuryBalance.gte(ethers.utils.parseEther('0.02')),
      'Incorrect treasury balance after withdraw'
    )
  })

  it('Mints licenses with extra tokens and redeems for them', async () => {
    // Alice makes a bond and buys a license with much more than needed
    const bondId = ethers.utils.formatBytes32String('testAliceBondId0')
    const benefactor = alice
    const benefactorBasisPoints = ethers.BigNumber.from('100')
    const purchasePrice = ethers.constants.WeiPerEther.mul('10') // 20 bucks
    const tokenName = 'testAliceTokenName'
    const tokenSymbol = 'TATS'
    const metadata = 'testAliceBondMetaData0'

    await autoBondAsAlice.createBond(
      bondId,
      benefactor,
      benefactorBasisPoints,
      purchasePrice,
      tokenName,
      tokenSymbol,
      metadata
    )

    const testLicenseUri = `example://metastore/${bondId}`
    const supply = await autoBond.supplyOf(bondId)
    const amount = practicalLinearCurveAmount(supply, purchasePrice.mul(100))
    const maxPrice = purchasePrice.mul(100).add(ethers.utils.parseEther('1'))
    await reserveToken.mint(alice, maxPrice)
    await reserveTokenAsAlice.approve(autoBond.address, maxPrice)

    assert((await squad.totalSupply()).eq(0), 'Incorrect starting supply')

    await squadAsAlice.mint(
      bondId,
      purchasePrice,
      maxPrice,
      amount,
      testLicenseUri
    )

    assert((await squad.totalSupply()).eq(1), 'Incorrect supply after mint')

    const tokenId = squad.tokenOfOwnerByIndex(alice, 0)

    // Alice redeems her license
    await squadAsAlice.redeem(tokenId)

    // Confirm that the NFT no longer exists
    assert((await squad.totalSupply()).eq(0), 'Incorrect supply after redeem')
    await expect(squad.ownerOf(tokenId)).to.be.revertedWith('ERC721: owner query for nonexistent token')

    // Confirm that Alice's balance has the claimed bond tokens
    assert(
      (await autoBondAsAlice.balance(bondId)).eq(amount),
      'Incorrect bond balance after redeem'
    )
  })

  it('Keeps accurate accounting through buys and sells', async () => {
    // Alice and Bob both make conributions
    const aliceBondId = ethers.utils.formatBytes32String('testAliceBondId0')
    const aliceBenefactor = alice
    const aliceBenefactorBasisPoints = ethers.BigNumber.from('100') // 1%
    const alicePurchasePrice = ethers.constants.WeiPerEther.mul('10') // 10 bucks
    const aliceTokenName = 'testAliceTokenName'
    const aliceTokenSymbol = 'TATS'
    const aliceMetadata = 'testAliceBondMetaData0'

    await autoBondAsAlice.createBond(
      aliceBondId,
      aliceBenefactor,
      aliceBenefactorBasisPoints,
      alicePurchasePrice,
      aliceTokenName,
      aliceTokenSymbol,
      aliceMetadata
    )
    const bobBondId = ethers.utils.formatBytes32String('testBobBondId0')
    const bobBenefactor = bob
    const bobBenefactorBasisPoints = ethers.BigNumber.from('5000') // 50%
    const bobPurchasePrice = ethers.constants.WeiPerEther.mul('2') // 2 bucks
    const bobTokenName = 'testBobTokenName'
    const bobTokenSymbol = 'TBTS'
    const bobMetadata = 'testBobBondMetaData0'

    await autoBondAsAlice.createBond(
      bobBondId,
      bobBenefactor,
      bobBenefactorBasisPoints,
      bobPurchasePrice,
      bobTokenName,
      bobTokenSymbol,
      bobMetadata
    )

    // confirm that autobond starts with zero reserve token
    assert(
      (await reserveToken.balanceOf(autoBond.address)).eq(0),
      'AutoBond started with nonzero reserve token'
    )

    assert((await squad.totalSupply()).eq(0), 'Incorrect starting supply')

    // Everyone buys a bunch of each
    async function mintOne (minterAddress, reserveTokenAsMinter, squadAsMinter, bondId, purchasePrice) {
      const testLicenseUri = `example://metastore/${bondId}`
      const supply = await autoBond.supplyOf(bondId)
      const amount = practicalLinearCurveAmount(supply, purchasePrice)
      const maxPrice = purchasePrice.add(ethers.utils.parseEther('1'))
      await reserveToken.mint(minterAddress, maxPrice)
      await reserveTokenAsMinter.approve(autoBond.address, maxPrice)

      await squadAsMinter.mint(
        bondId,
        purchasePrice,
        maxPrice,
        amount,
        testLicenseUri
      )
    }
    // alice buys 3 of each
    await mintOne(alice, reserveTokenAsAlice, squadAsAlice, aliceBondId, alicePurchasePrice)
    await mintOne(alice, reserveTokenAsAlice, squadAsAlice, aliceBondId, alicePurchasePrice)
    await mintOne(alice, reserveTokenAsAlice, squadAsAlice, aliceBondId, alicePurchasePrice)
    await mintOne(alice, reserveTokenAsAlice, squadAsAlice, bobBondId, bobPurchasePrice)
    await mintOne(alice, reserveTokenAsAlice, squadAsAlice, bobBondId, bobPurchasePrice)
    await mintOne(alice, reserveTokenAsAlice, squadAsAlice, bobBondId, bobPurchasePrice)

    // Bob buys 1 of each
    await mintOne(bob, reserveTokenAsBob, squadAsBob, aliceBondId, alicePurchasePrice)
    await mintOne(bob, reserveTokenAsBob, squadAsBob, bobBondId, bobPurchasePrice)

    // Carol buys 2 of each
    await mintOne(carol, reserveTokenAsCarol, squadAsCarol, aliceBondId, alicePurchasePrice)
    await mintOne(carol, reserveTokenAsCarol, squadAsCarol, aliceBondId, alicePurchasePrice)
    await mintOne(carol, reserveTokenAsCarol, squadAsCarol, bobBondId, bobPurchasePrice)
    await mintOne(carol, reserveTokenAsCarol, squadAsCarol, bobBondId, bobPurchasePrice)

    // confirm that autobond has the right amount of reserve token
    // 6 of each were bought so autobond should have >= 6*alicePurchasePrice + 6*bobPurchasePrice
    assert(
      (await reserveToken.balanceOf(autoBond.address)).gte(alicePurchasePrice.mul(6).add(bobPurchasePrice.mul(6))),
      'Incorrect autoBond reserveToken balance after mints'
    )

    // everyone redeems all their licenses
    async function redeemOne (redeemerAddress, squadAsRedeemer, tokenIndex) {
      const licenseId = await squadAsRedeemer.tokenOfOwnerByIndex(redeemerAddress, tokenIndex)
      return squadAsRedeemer.redeem(licenseId)
    }
    await redeemOne(alice, squadAsAlice, 0)
    await redeemOne(alice, squadAsAlice, 0)
    await redeemOne(alice, squadAsAlice, 0)
    await redeemOne(alice, squadAsAlice, 0)
    await redeemOne(alice, squadAsAlice, 0)
    await redeemOne(alice, squadAsAlice, 0)

    await redeemOne(bob, squadAsBob, 0)
    await redeemOne(bob, squadAsBob, 0)

    await redeemOne(carol, squadAsCarol, 0)
    await redeemOne(carol, squadAsCarol, 0)
    await redeemOne(carol, squadAsCarol, 0)
    await redeemOne(carol, squadAsCarol, 0)

    // confirm that squad has almost no bond tokens
    assert((await autoBond.balanceOf(aliceBondId, squad.address)).eq(0),
      'Squad A bond balance too high')
    assert((await autoBond.balanceOf(bobBondId, squad.address)).eq(0),
      'Squad B bond balance too high')

    // everyone sells their bond tokens
    function sellAllBondTokens (bondIds, autoBondAsSeller) {
      bondIds.forEach((bondId) => {
        const amount = autoBondAsSeller.balance(bondId)
        autoBondAsSeller.sellTokens(bondId, amount, 0)
      })
    }

    sellAllBondTokens([aliceBondId, bobBondId], autoBondAsAlice)
    sellAllBondTokens([aliceBondId, bobBondId], autoBondAsBob)
    sellAllBondTokens([aliceBondId, bobBondId], autoBondAsCarol)

    await autoBondAsAlice.withdraw()
    await autoBondAsBob.withdraw()
    await autoBond.recoverReserveDust()

    // confirm that autoBond has almost no reserveToken
    assert((await reserveToken.balanceOf(autoBond.address)).eq(0),
      'AutoBond left with too much reserve token after sale')

    // confirm that the total reserve token holdings of autoBond,
    // Alice, Bob, and Carol is close to the purchase price of 6 of
    // each license (plus the 6 token buffers each for max price).
    const aliceTotal = await reserveToken.balanceOf(alice)
    const bobTotal = await reserveToken.balanceOf(bob)
    const carolTotal = await reserveToken.balanceOf(carol)
    const treasuryTotal = await reserveToken.balanceOf(treasury)

    assert(
      aliceTotal.add(bobTotal).add(carolTotal).add(treasuryTotal).eq(
        alicePurchasePrice.mul(6).add(bobPurchasePrice.mul(6)).add(ethers.utils.parseEther('12'))
      ),
      "Balances don't add up after buys, sells, and withdraws"
    )
  })

  // Curating
  it.skip('Lets Carol curate/invest in the bond', async () => {
    assert(false, 'Not Implemented')
  })
})
