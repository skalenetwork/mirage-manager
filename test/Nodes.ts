import { ethers } from "hardhat";
import { expect } from "chai";
import { cleanDeployment } from "./fixtures";


describe("Nodes", function () {
    it("should run test", async () => {
        const {nodes} = await cleanDeployment();
        expect(await nodes.REMOVE()).to.equal(5n);
    });

    it("should restrict access", async () => {
        const {nodes} = await cleanDeployment();
        await expect(nodes.registerNode("0x", 0))
            .to.be.revertedWithCustomError(nodes, "NotImplemented");
        const [,hacker] = await ethers.getSigners();
        await expect(nodes.connect(hacker).registerNode("0x", 0))
            .to.be.revertedWithCustomError(nodes, "AccessManagedUnauthorized");
    });
});
