const { expectRevert } = require('@openzeppelin/test-helpers')

contract("RightsDao", (accounts) => {

  const RightsDao = artifacts.require("RightsDao");
  const FRight = artifacts.require("FRight");
  const IRight = artifacts.require("IRight");
  const NFT = artifacts.require("TradeableERC721Token");

  const owner = accounts[0]
  const API_BASE_URL = "https://rinkeby-rightshare-metadata.lendroid.com/api/v1/"

  let dao, fRight, iRight, nft

  beforeEach(async () => {
    dao = await RightsDao.deployed()
    fRight = await FRight.deployed()
    iRight = await IRight.deployed()
    nft = await NFT.deployed()
  })

  describe('constructor', () => {
    it('deploys with owner', async () => {
      assert.equal(owner, await dao.owner(), "owner is not deployer")
    })
  })

  describe('set_right', () => {
    it('allows owner to set f right', async () => {
      // Confirm f right contract address has not been set to 0x0
      assert.equal(await dao.contracts(1), 0x0, "f right contract address is not 0x0.")
      // call with invalid contract type will revert
      await expectRevert(
        dao.set_right(0, fRight.address, {from: owner}),
        'invalid contract type',
      )
      await expectRevert(
        dao.set_right(3, fRight.address, {from: owner}),
        'invalid contract type',
      )
      // Set f right contract address
      await dao.set_right(1, fRight.address, {from: owner})
      // Confirm f right contract address
      assert.equal(await dao.contracts(1), fRight.address, "f right address has not been set correctly.")
      // call by non owner will revert
      await expectRevert(
        dao.set_right(1, nft.address, {from: accounts[1]}),
        'invalid sender',
      )
      // call with invalid contract address will revert
      await expectRevert(
        dao.set_right(1, owner, {from: owner}),
        'invalid contract address',
      )
      // call with 0x0 as contract address will revert
      await expectRevert(
        dao.set_right(1, 0x0, {from: owner}),
        'invalid address',
      )
    })

    it('allows owner to set i right', async () => {
      // Confirm f right contract address has not been set to 0x0
      assert.equal(await dao.contracts(2), 0x0, "i right contract address is not 0x0.")
      // call with invalid contract type will revert
      await expectRevert(
        dao.set_right(0, iRight.address, {from: owner}),
        'invalid contract type',
      )
      await expectRevert(
        dao.set_right(3, iRight.address, {from: owner}),
        'invalid contract type',
      )
      // Set i right contract address
      await dao.set_right(2, iRight.address, {from: owner})
      // Confirm i right contract address
      assert.equal(await dao.contracts(2), iRight.address, "i right address has not been set correctly.")
      // call by non owner will revert
      await expectRevert(
        dao.set_right(2, nft.address, {from: accounts[1]}),
        'invalid sender',
      )
      // call with invalid contract address will revert
      await expectRevert(
        dao.set_right(2, owner, {from: owner}),
        'invalid contract address',
      )
      // call with 0x0 as contract address will revert
      await expectRevert(
        dao.set_right(2, 0x0, {from: owner}),
        'invalid address',
      )
    })
  })
});