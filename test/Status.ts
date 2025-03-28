import { ethers } from "hardhat";
import { expect } from "chai";
import { with5ActiveNodesDeployment } from "./fixtures";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { Nodes, Status } from "../typechain-types";


chai.should();
chai.use(chaiAsPromised)

describe("Nodes", function () {

    let nodesContract: Nodes;
    let statusContract: Status;
    // owns node 1
    let user1: HardhatEthersSigner;
    // owns node 2
    let user2: HardhatEthersSigner;
    // owns node 3
    let user3: HardhatEthersSigner;
    // owns node 4
    let user4: HardhatEthersSigner;
    // owns node 5
    let user5: HardhatEthersSigner;
    // does not own nodes
    let user6: HardhatEthersSigner;

    beforeEach(async () => {
        const {nodes, status} = await with5ActiveNodesDeployment();
        nodesContract = nodes;
        statusContract = status;
        [, user1, user2, user3, user4, user5, user6] = await ethers.getSigners();
    });

    it("should allow only creator to whitelist nodes", async () => {
        await expect(statusContract.connect(user1).whitelistNode(1)).to.be.reverted;

        await statusContract.whitelistNode(1);

        expect(await statusContract.getWhitelistedNodes()).to.eql([1n]);
    });
    it("should revert if node is already whitelisted", async () => {
        await statusContract.whitelistNode(1);
        expect(await statusContract.getWhitelistedNodes()).to.eql([1n]);
        await expect(statusContract.whitelistNode(1))
        .to.be.revertedWithCustomError(statusContract, "NodeAlreadyWhitelisted");
    });
    it("should revert if node does not exist", async () => {
        await expect(statusContract.whitelistNode(6))
        .to.be.revertedWithCustomError(nodesContract, "NodeDoesNotExist");
    });

    it("should revert if node is not whitelisted", async () => {
        await expect(statusContract.removeNodeFromWhitelist(6))
        .to.be.revertedWithCustomError(statusContract, "NodeNotWhitelisted");
    });
    it("should ensure alive() registers correctly", async () => {
        expect(await statusContract.lastHeartbeatTimestamp(1)).to.eql(0n);

        await statusContract.connect(user1).alive();
        const firstTimestamp = await statusContract.lastHeartbeatTimestamp(1);
        expect(firstTimestamp).to.be.greaterThan(0n);

        await statusContract.connect(user1).alive();
        const secondTimestamp = await statusContract.lastHeartbeatTimestamp(1);

        expect(secondTimestamp).to.be.greaterThan(firstTimestamp);
    });
    it("should revert alive() if node does not exist for sender", async () => {
        await expect(statusContract.connect(user6).alive())
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode")
    });

    it("should allow only creator to set new heartbeat interval", async () => {
        await expect(statusContract.connect(user1).setHeartbeatInterval(1)).to.be.reverted;
        expect(await statusContract.heartbeatInterval()).to.eql(0n);
        await statusContract.setHeartbeatInterval(1);
        expect(await statusContract.heartbeatInterval()).to.eql(1n);
    });
    it("should allow only creator to remove node from whitelist", async () => {
        await statusContract.whitelistNode(1);
        expect(await statusContract.getWhitelistedNodes()).to.eql([1n]);

        await expect(statusContract.connect(user1).removeNodeFromWhitelist(1)).to.be.reverted;

        await statusContract.removeNodeFromWhitelist(1);

        expect(await statusContract.getWhitelistedNodes()).to.eql([]);

    });
    it("should accurately change healthy status of node", async () => {
        await statusContract.setHeartbeatInterval(60);
        expect(await statusContract.isHealthy(1)).to.eql(false);

        await statusContract.connect(user1).alive();
        // healthy for 60 seconds interval
        expect(await statusContract.isHealthy(1)).to.eql(true);

        await statusContract.setHeartbeatInterval(1);
        // unhealthy for 1 second interval
        expect(await statusContract.isHealthy(1)).to.eql(false);

    });

    it("should accurately select nodes eligible for committee", async () => {
        await statusContract.setHeartbeatInterval(60);


        await statusContract.connect(user1).alive();
        await statusContract.connect(user2).alive();
        await statusContract.connect(user3).alive();
        await statusContract.connect(user4).alive();
        await statusContract.connect(user5).alive();
        // No nodes whitelisted
        expect(await statusContract.getNodesEligibleForCommittee()).to.eql([]);

        await statusContract.whitelistNode(1);
        await statusContract.whitelistNode(2);
        await statusContract.whitelistNode(3);
        await statusContract.whitelistNode(4);
        await statusContract.whitelistNode(5);

        const healthy = await statusContract.getNodesEligibleForCommittee();

        expect(healthy.length).to.equal(5);

        await statusContract.setHeartbeatInterval(2);
        // wait 2 seconds
        await new Promise(resolve => setTimeout(resolve, 2000));

        await statusContract.connect(user1).alive();

        const healthyV2 = await statusContract.getNodesEligibleForCommittee();
        expect(healthyV2).to.eql([1n]);

    });
});
