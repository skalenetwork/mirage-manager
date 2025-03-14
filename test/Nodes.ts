import {ethers} from "hardhat";
import { expect } from "chai";

describe("Nodes", function () {
    it("should run test", async () => {
        const Nodes = await ethers.getContractFactory("Nodes");
        const nodes = await Nodes.deploy();
        expect(await nodes.REMOVE()).to.equal(5n);
    });
});
