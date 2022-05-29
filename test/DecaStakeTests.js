const DecaToken = artifacts.require("DecaToken");
const CornToken = artifacts.require("CornToken");
const DecaStake = artifacts.require("DecaStake");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
var decaInstance;
var cornInstance;
var stakeInstance;
const DEAD_ADDR = "0x000000000000000000000000000000000000dEaD";

contract("DecaStake", function (accounts) {
	beforeEach(async () => {
		decaInstance = await DecaToken.deployed();
        cornInstance = await CornToken.deployed();
        stakeInstance = await DecaStake.deployed();
	});

    it("should return true when compare deca token address and deca address in contract", async function () {

		var decaToken = await stakeInstance.decaToken();
		assert.equal(decaToken.toString(), decaInstance.address.toString());
	});

    it("should return true when compare corn token address and corn address in contract", async function () {

		var cornToken = await stakeInstance.cornToken();
		assert.equal(cornToken.toString(), cornInstance.address.toString());
	});

    it("should return true when feeReceiver is the same with contract owner", async function () {

        var owner = await stakeInstance.owner();
		var feeReceiver = await stakeInstance.feeReceiver();
		assert.equal(owner.toString(), feeReceiver.toString());
	});

    it("should return true if setDecaToken is updated successfully", async function () {

        var result = await stakeInstance.setDecaToken(DEAD_ADDR);
        assert.isTrue(result.receipt.status);

        var token = await stakeInstance.decaToken();
		assert.equal(token.toString(), DEAD_ADDR);
	});

    it("should return true if setCornToken is updated successfully", async function () {

        var result = await stakeInstance.setCornToken(DEAD_ADDR);
        assert.isTrue(result.receipt.status);

        var token = await stakeInstance.cornToken();
		assert.equal(token.toString(), DEAD_ADDR);
	});

    it("should return true if setRewardPeriod is updated successfully", async function () {

        var newRewardPeriod = 100;
        var result = await stakeInstance.setRewardPeriod(newRewardPeriod);
        assert.isTrue(result.receipt.status);

        var rewardPeriod = await stakeInstance.rewardPeriod();
		assert.equal(rewardPeriod.toString(), newRewardPeriod.toString());
	});

    it("should return true if setUnstakeFee is updated successfully", async function () {

        var newUnstakeFee = 5;
        var result = await stakeInstance.setUnstakeFee(newUnstakeFee);
        assert.isTrue(result.receipt.status);

        var unstakeFee = await stakeInstance.unstakeFee();
		assert.equal(unstakeFee.toString(), newUnstakeFee.toString());
	});

    it("should return zero poolLength when the contract are freshly created", async function () {

        var poolLength = await stakeInstance.poolLength();
		assert.equal(poolLength.toString(), "0");
	});

    it("should return correct poolLength if registerPool successfully", async function () {
        
        var count = 2;
        for(let i=0; i<count; i++) {
            var result = await registerPool(toWei(1000), toWei(1000));
            assert.isTrue(result);
        }
        
        var poolLength = await stakeInstance.poolLength();
		assert.equal(poolLength.toString(), count.toString());
	});

    it("should return false if updatePool on non-exist pool", async function () {
        
        var poolLength = await stakeInstance.poolLength();

        // pool index starts from zero. if use poolLength is non-exist pool
        var result = await updatePool(poolLength, toWei(2000), toWei(2000), true);
        assert.isFalse(result);
	});

    it("should return true if updatePool successfully", async function () {
        var result = await updatePool(0, toWei(2000), toWei(3000), true);
        assert.isTrue(result);

        var poolInfo = await stakeInstance.poolInfo(0);
        // console.log("poolInfo", poolInfo);
        assert.equal(poolInfo.rate.toString(), toWei(2000).toString());
        assert.equal(poolInfo.stakeLimit.toString(), toWei(3000).toString());
        assert.equal(poolInfo.paused, true);
	});

    
	
});

async function stake(pid, amount) {

	try {
		var result = await stakeInstance.stake(pid, amount);
		assert.isTrue(result.receipt.status);

	} catch(Exception) {
        console.log(Exception);
		return false;
	}

	return true;
}

async function unstake(pid) {

	try {
		var result = await stakeInstance.unstake(pid);
		assert.isTrue(result.receipt.status);

	} catch(Exception) {
        console.log(Exception);
		return false;
	}

	return true;
}

async function harvest(pid) {

	try {
		var result = await stakeInstance.harvest(pid);
		assert.isTrue(result.receipt.status);

	} catch(Exception) {
        console.log(Exception);
		return false;
	}

	return true;
}

async function registerPool(rate, stakeLimit) {

	try {
		var result = await stakeInstance.registerPool(rate, stakeLimit);
		assert.isTrue(result.receipt.status);

	} catch(Exception) {
        //console.log(Exception);
		return false;
	}

	return true;
}

async function updatePool(pid, rate, stakeLimit, paused) {

	try {
		var result = await stakeInstance.updatePool(pid, rate, stakeLimit, paused);
		assert.isTrue(result.receipt.status);

	} catch(Exception) {
        //console.log(Exception);
		return false;
	}

	return true;
}

function toWei(count) {
	return web3.utils.toWei(toBN(count));
}

function toBN(value) {
	return web3.utils.toBN(value);
}

function timeout(ms) {
	return new Promise(resolve => setTimeout(resolve, ms));
}