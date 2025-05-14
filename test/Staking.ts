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
});
