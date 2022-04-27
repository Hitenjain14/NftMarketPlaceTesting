const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

let Marketplace;
let proxy;
let NftCol;
let accounts;

describe('Marketplace(proxy)', function () {
  beforeEach(async function () {
    const nftCol = await ethers.getContractFactory('BottleNft');
    accounts = await ethers.getSigners();

    NftCol = await nftCol
      .connect(accounts[0])
      .deploy('https://api/image/', 1000, 20);

    Marketplace = await ethers.getContractFactory('MarketPlace');
    proxy = await upgrades.deployProxy(Marketplace, [NftCol.address]);
    await NftCol.connect(accounts[0]).mint(accounts[0].address, 10);
  });

  it('retrieve address', async function () {
    expect((await proxy.nftAddress()).toString()).to.equal(NftCol.address);
  });

  it('start auction', async function () {
    let asserted = false;

    try {
      await NftCol.connect(accounts[0]).setApprovalForAll(proxy.address, true);

      const aucTxn = await proxy
        .connect(accounts[0])
        .startAuction(1, ethers.utils.parseEther('1'), 1000);

      const AucTxn = await aucTxn.wait();
      console.log('Gas used to start auction', AucTxn.gasUsed.toString());

      const cancelTxn = await proxy.connect(accounts[0]).cancelAuction(1);

      const CancelTxn = await cancelTxn.wait();
      console.log('Gas used to cancel auction', CancelTxn.gasUsed.toString());

      const auc1Txn = await proxy
        .connect(accounts[0])
        .startAuction(1, ethers.utils.parseEther('1'), 1000);

      const Auc1Txn = await auc1Txn.wait();

      console.log(
        'Gas used to start auction 2nd time',
        Auc1Txn.gasUsed.toString()
      );
    } catch (err) {
      asserted = true;
    }
    // console.log(await proxy.Auctions(1));
    // expect((await NftCol.ownerOf(1)).toString()).to.equal(accounts[0].address);
    expect((await NftCol.ownerOf(1)).toString()).to.equal(proxy.address);
  });

  it('bidding different times, claiming asset,bid and withdrawing', async function () {
    let asserted = false;
    try {
      await NftCol.connect(accounts[0]).setApprovalForAll(proxy.address, true);
      await proxy
        .connect(accounts[0])
        .startAuction(1, ethers.utils.parseEther('1'), 100);

      const bidTrx = await proxy
        .connect(accounts[1])
        .bid(1, { value: ethers.utils.parseEther('1') });

      const BidTxn = await bidTrx.wait();
      console.log('Gas used in bidding', BidTxn.gasUsed.toString());
      await proxy.connect(accounts[2]).bid(1, {
        value: ethers.utils.parseEther('2'),
      });

      const txn = await proxy
        .connect(accounts[1])
        .bid(1, { value: ethers.utils.parseEther('2') });

      const Txn = await txn.wait();
      console.log('Gas used in bidding 2nd time', Txn.gasUsed.toString());
      await proxy.connect(accounts[2]).bid(1, {
        value: ethers.utils.parseEther('2'),
      });
      console.log(await accounts[1].getBalance());
      await proxy.connect(accounts[1]).withdrawBid(1);
      console.log(await accounts[1].getBalance());

      await proxy.connect(accounts[0]).endAuc(1);
      await proxy.connect(accounts[0]).endAuction(1);

      const val = await proxy.toPay(accounts[0].address);
      console.log(val.toString());

      await proxy.connect(accounts[2]).claimAsset(1);
    } catch (err) {
      asserted = true;
    }
    expect((await NftCol.ownerOf(1)).toString()).to.equal(accounts[2].address);
  });

  it('instantBuy', async function () {
    let asserted = false;
    try {
      await NftCol.connect(accounts[0]).setApprovalForAll(proxy.address, true);

      await proxy
        .connect(accounts[0])
        .setPrice(1, ethers.utils.parseEther('1'));

      const instTxn = await proxy
        .connect(accounts[1])
        .instantBuy(1, { value: ethers.utils.parseEther('1') });

      const InstTxn = await instTxn.wait();

      console.log('Gas used for instant buy', InstTxn.gasUsed.toString());
    } catch (err) {
      asserted = true;
    }
    expect(asserted).to.equal(false);
    expect((await NftCol.ownerOf(1)).toString()).to.equal(accounts[1].address);
  });
});
