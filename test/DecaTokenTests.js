const DecaToken = artifacts.require("DecaToken");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
var instance;

contract("DecaToken", function (accounts) {
	beforeEach(async () => {
		instance = await DecaToken.deployed();
	});

	it("should return correct token name", async function () {
		var name = await instance.name();

		assert.equal(name, "DECA TOKEN");
	});

	it("should return correct token symbol", async function () {
		var symbol = await instance.symbol();

		assert.equal(symbol, "DECA");
	});

	it('should return a balance of zero for an address that has no tokens ', async function () {
		var balance = await instance.balanceOf(accounts[1]);
		assert.equal(balance, 0);
	});

	it("should transfer 1,000,000,000 TNG", async function () {
		var amount = toWei(10);
		var totalSupply = await instance.totalSupply();

		await instance.transfer(accounts[1], web3.utils.toBN(amount));

		var balanceAccount0 = (await instance.balanceOf(accounts[0])).toString();
		var balanceAccount1 = (await instance.balanceOf(accounts[1])).toString();

		assert.equal(balanceAccount0, totalSupply - amount);
		assert.equal(balanceAccount1, amount);
	});

	it('should fail if account dont have tokens', async () => {
		var hasError = false;
		try {
			var amount = toWei(10);
			await instance.transfer(accounts[0], amount, { from: accounts[1] })

			hasError = false; // Should be unreachable
		} catch (err) {
			hasError = true;
		}

		assert.equal(true, hasError, "Holder do not have enough tokens");
	});
});

function toWei(count) {
	return count * 10 ** 18
}
