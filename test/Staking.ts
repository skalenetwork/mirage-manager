import chai from "chai";
import { nodesRegisteredButNotWhitelisted } from "./tools/fixtures";
import { ethers } from "hardhat";

chai.should();

describe("Staking", () => {
    it("should allow holder to stake", async () => {
        const {staking, nodesData } = await nodesRegisteredButNotWhitelisted();
        const [,user] = await ethers.getSigners();
        const amount = ethers.parseEther("1");
        const node = nodesData[0].id;
        await staking.connect(user).stake(node, {value: amount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount);
    });

    it("should distribute rewards proportionally to stake", async () => {
        const {staking, nodesData } = await nodesRegisteredButNotWhitelisted();
        const [owner, user1, user2] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const reward = ethers.parseEther("5");
        const node = nodesData[0].id;

        await staking.connect(user1).stake(node, {value: amount1});
        await staking.connect(user2).stake(node, {value: amount2});

        // Pay reward
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.connect(user1).getStakedAmount())
            .should.be.equal(amount1 + reward * amount1 / (amount1 + amount2));
        (await staking.connect(user2).getStakedAmount())
            .should.be.equal(amount2 + reward * amount2 / (amount1 + amount2));
    });

    it("should be able to stake to multiple nodes", async () => {
        const {staking, nodesData } = await nodesRegisteredButNotWhitelisted();
        const [, user] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const [node1, node2] = [nodesData[0].id, nodesData[1].id];

        await staking.connect(user).stake(node1, {value: amount1});
        await staking.connect(user).stake(node2, {value: amount2});

        (await staking.connect(user).getStakedNodes())
            .map(BigInt)
            .should.have.members([node1, node2]);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount1 + amount2);
        (await staking.connect(user).getStakedToNodeAmount(node1))
            .should.be.equal(amount1);
        (await staking.connect(user).getStakedToNodeAmount(node2))
            .should.be.equal(amount2);
    });

    it("should be possible to retrieve", async () => {
        const {staking, nodesData } = await nodesRegisteredButNotWhitelisted();
        const [,user] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("1");
        const node = nodesData[0].id;

        await staking.connect(user).stake(node, {value: initialAmount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);
        await staking.connect(user).retrieve(node, amount)
            .should.changeEtherBalance(user, amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount - amount);
    });

    it("should apply validator fee on rewards", async () => {
        const {staking, nodesData } = await nodesRegisteredButNotWhitelisted();
        const [owner,user] = await ethers.getSigners();
        const amount = ethers.parseEther("1");
        const reward = ethers.parseEther("2");
        const feeRate = 500; // Yes, Eddie, half
        const {id: node, wallet: nodeWallet} = nodesData[0];

        await staking.connect(nodeWallet).setFeeRate(feeRate);
        await staking.connect(user).stake(node, {value: amount});
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.getEarnedFeeAmount(node))
            .should.be.equal(reward / 2n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(amount + reward / 2n);

        await staking.connect(nodeWallet).claimAllFee(nodeWallet)
            .should.changeEtherBalance(nodeWallet, reward / 2n);
        await staking.connect(user).retrieve(node, amount + reward / 2n)
            .should.changeEtherBalance(user, amount + reward / 2n);

        (await staking.getEarnedFeeAmount(node))
            .should.be.equal(0n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(0n);
    });
});
