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
});
