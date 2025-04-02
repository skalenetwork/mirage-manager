import { expect } from "chai";
import { nodesRegistered } from "./fixtures";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { Nodes, Status } from "../typechain-types";
import { HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";


chai.should();
chai.use(chaiAsPromised)

describe("Status", function () {

    let nodesContract: Nodes;
    let statusContract: Status;
    // owns node 1
    let user1: HDNodeWallet;
    // owns node 2
    let user2: HDNodeWallet;
    // owns node 3
    let user3: HDNodeWallet;
    // owns node 4
    let user4: HDNodeWallet;
    // owns node 5
    let user5: HDNodeWallet;
    // does not own nodes
    let randomUser: HDNodeWallet;

    beforeEach(async () => {
        const { nodes, status , nodesData } = await nodesRegistered();
        nodesContract = nodes;
        statusContract = status;
        user1 = nodesData[0].wallet;
        user2 = nodesData[1].wallet;
        user3 = nodesData[2].wallet;
        user4 = nodesData[3].wallet;
        user5 = nodesData[4].wallet;
        randomUser = Wallet.createRandom().connect(ethers.provider);
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
        // 50 nodes registered
        await expect(statusContract.whitelistNode(51))
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
        await expect(statusContract.connect(randomUser).alive())
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
