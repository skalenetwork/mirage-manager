import { expect } from "chai";
import { registeredOnlyNodes } from "./tools/fixtures";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import ip from "ip";
import { Nodes, Status } from "../typechain-types";
import { BigNumberish, HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";

chai.should();
chai.use(chaiAsPromised)

const MOCK_IP_0 = "192.168.0.1"
const MOCK_IP_0_BYTES = ip.toBuffer(MOCK_IP_0);

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
    let nodeIdForUser1: BigNumberish;
    let nodeIdForUser2: BigNumberish;
    let nodeIdForUser3: BigNumberish;
    let nodeIdForUser4: BigNumberish;
    let nodeIdForUser5: BigNumberish;
    let passiveNodeId: BigNumberish;

    beforeEach(async () => {
        const { nodes, status , nodesData } = await registeredOnlyNodes();
        nodesContract = nodes;
        statusContract = status;

        // Last five are not in the first committee so we can test node deletion
        const lastFiveNodes = nodesData.slice(-5);
        [user1, user2, user3, user4, user5] = lastFiveNodes.map(({ wallet }) => wallet);
        [nodeIdForUser1, nodeIdForUser2, nodeIdForUser3, nodeIdForUser4, nodeIdForUser5] =
            [user1, user2, user3, user4, user5].map(user =>
                lastFiveNodes.find(node => node.wallet.address === user.address)!.id
            );
        randomUser = Wallet.createRandom().connect(ethers.provider);

        // Random user registers a passive node
        await setBalance(randomUser.address, ethers.parseEther("1000"));
        await nodesContract.connect(randomUser).registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        [passiveNodeId] = await nodesContract.getPassiveNodeIdsForAddress(randomUser.address);
    });

    it("should allow only creator to whitelist nodes", async () => {
        await expect(statusContract.connect(user1).whitelistNode(nodeIdForUser1)).to.be.reverted;

        await statusContract.whitelistNode(nodeIdForUser1);

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([nodeIdForUser1]);
        expect(await statusContract.isWhitelisted(nodeIdForUser1)).to.eql(true);
    });

    it("should whitelist and distinguish passive and active nodes", async () => {
        await expect(statusContract.whitelistNode(nodeIdForUser1)).to.emit(statusContract, "ActiveNodeWhitelisted");
        await expect(statusContract.whitelistNode(passiveNodeId)).to.emit(statusContract, "PassiveNodeWhitelisted");

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([nodeIdForUser1]);
        expect(await statusContract.isWhitelisted(nodeIdForUser1)).to.eql(true);

        expect(await statusContract.getWhitelistedPassiveNodes()).to.eql([passiveNodeId]);
        expect(await statusContract.isPassiveWhitelisted(passiveNodeId)).to.eql(true);

        expect(await statusContract.isPassiveWhitelisted(nodeIdForUser1)).to.eql(false);
        expect(await statusContract.isWhitelisted(passiveNodeId)).to.eql(false);
    });

    it("should allow to blacklist nodes", async () => {
        await expect(statusContract.whitelistNode(nodeIdForUser1)).to.emit(statusContract, "ActiveNodeWhitelisted");
        await expect(statusContract.whitelistNode(passiveNodeId)).to.emit(statusContract, "PassiveNodeWhitelisted");

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([nodeIdForUser1]);
        expect(await statusContract.isWhitelisted(nodeIdForUser1)).to.eql(true);

        expect(await statusContract.getWhitelistedPassiveNodes()).to.eql([passiveNodeId]);
        expect(await statusContract.isPassiveWhitelisted(passiveNodeId)).to.eql(true);

        expect(await statusContract.isPassiveWhitelisted(nodeIdForUser1)).to.eql(false);
        expect(await statusContract.isWhitelisted(passiveNodeId)).to.eql(false);

        await expect(statusContract.removeNodeFromWhitelist(nodeIdForUser1)).to.emit(statusContract, "ActiveNodeRemovedFromWhitelist");
        await expect(statusContract.removeNodeFromWhitelist(passiveNodeId)).to.emit(statusContract, "PassiveNodeRemovedFromWhitelist");

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([]);
        expect(await statusContract.getWhitelistedPassiveNodes()).to.eql([]);
        expect(await statusContract.isWhitelisted(nodeIdForUser1)).to.eql(false);
        expect(await statusContract.isPassiveWhitelisted(passiveNodeId)).to.eql(false);
    });

    it("deleting nodes should remove them from whitelist", async () => {
        await expect(statusContract.whitelistNode(nodeIdForUser1)).to.emit(statusContract, "ActiveNodeWhitelisted");
        await expect(statusContract.whitelistNode(passiveNodeId)).to.emit(statusContract, "PassiveNodeWhitelisted");

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([nodeIdForUser1]);
        expect(await statusContract.isWhitelisted(nodeIdForUser1)).to.eql(true);

        expect(await statusContract.getWhitelistedPassiveNodes()).to.eql([passiveNodeId]);
        expect(await statusContract.isPassiveWhitelisted(passiveNodeId)).to.eql(true);

        expect(await statusContract.isPassiveWhitelisted(nodeIdForUser1)).to.eql(false);
        expect(await statusContract.isWhitelisted(passiveNodeId)).to.eql(false);

        await nodesContract.connect(user1).deleteNode(nodeIdForUser1);
        await nodesContract.connect(randomUser).deleteNode(passiveNodeId);

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([]);
        expect(await statusContract.getWhitelistedPassiveNodes()).to.eql([]);
        expect(await statusContract.isWhitelisted(nodeIdForUser1)).to.eql(false);
        expect(await statusContract.isPassiveWhitelisted(passiveNodeId)).to.eql(false);

        await expect(statusContract.whitelistNode(nodeIdForUser1)).to.be.revertedWithCustomError(statusContract, "NodeDoesNotExist");
        await expect(statusContract.whitelistNode(passiveNodeId)).to.be.revertedWithCustomError(statusContract, "NodeDoesNotExist");
    });

    it("should revert if node is already whitelisted", async () => {
        await statusContract.whitelistNode(nodeIdForUser1);
        await statusContract.whitelistNode(passiveNodeId);
        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([nodeIdForUser1]);
        expect(await statusContract.getWhitelistedPassiveNodes()).to.eql([passiveNodeId]);
        await expect(statusContract.whitelistNode(nodeIdForUser1))
        .to.be.revertedWithCustomError(statusContract, "NodeAlreadyWhitelisted");
        await expect(statusContract.whitelistNode(passiveNodeId))
        .to.be.revertedWithCustomError(statusContract, "NodeAlreadyWhitelisted");
    });

    it("should revert if node does not exist", async () => {
        const nonExistentNodeId = 1000;
        await expect(statusContract.whitelistNode(nonExistentNodeId))
        .to.be.revertedWithCustomError(nodesContract, "NodeDoesNotExist");
    });

    it("should revert if node is not whitelisted", async () => {
        await expect(statusContract.removeNodeFromWhitelist(6))
        .to.be.revertedWithCustomError(statusContract, "NodeNotWhitelisted");
    });

    it("should ensure alive() registers correctly", async () => {
        expect(await statusContract.lastHeartbeatTimestamp(nodeIdForUser1)).to.eql(0n);
        await statusContract.connect(user1).alive();
        const firstTimestamp = await statusContract.lastHeartbeatTimestamp(nodeIdForUser1);
        expect(firstTimestamp).to.be.greaterThan(0n);

        await statusContract.connect(user1).alive();
        const secondTimestamp = await statusContract.lastHeartbeatTimestamp(nodeIdForUser1);

        expect(secondTimestamp).to.be.greaterThan(firstTimestamp);
    });

    it("should revert alive() if Active node does not exist for sender", async () => {
        await expect(statusContract.connect(randomUser).alive())
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode")
    });

    it("should allow only creator to set new heartbeat interval", async () => {
        await expect(statusContract.connect(user1).setHeartbeatInterval(1)).to.be.reverted;
        expect(await statusContract.heartbeatInterval()).to.eql(5n * 60n);
        await statusContract.setHeartbeatInterval(1);
        expect(await statusContract.heartbeatInterval()).to.eql(1n);
    });

    it("should allow only creator to remove node from whitelist", async () => {
        await statusContract.whitelistNode(nodeIdForUser1);
        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([nodeIdForUser1]);

        await expect(statusContract.connect(user1).removeNodeFromWhitelist(1)).to.be.reverted;

        await statusContract.removeNodeFromWhitelist(nodeIdForUser1);

        expect(await statusContract.getWhitelistedActiveNodes()).to.eql([]);

    });

    it("should accurately change healthy status of node", async () => {
        await statusContract.setHeartbeatInterval(60);
        expect(await statusContract.isHealthy(nodeIdForUser1)).to.eql(false);

        await statusContract.connect(user1).alive();
        // healthy for 60 seconds interval
        expect(await statusContract.isHealthy(nodeIdForUser1)).to.eql(true);

        await statusContract.setHeartbeatInterval(1);
        // unhealthy for 1 second interval
        expect(await statusContract.isHealthy(nodeIdForUser1)).to.eql(false);

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

        await statusContract.whitelistNode(nodeIdForUser1);
        await statusContract.whitelistNode(nodeIdForUser2);
        await statusContract.whitelistNode(nodeIdForUser3);
        await statusContract.whitelistNode(nodeIdForUser4);
        await statusContract.whitelistNode(nodeIdForUser5);

        const healthy = await statusContract.getNodesEligibleForCommittee();

        expect(healthy.length).to.equal(5);

        await statusContract.setHeartbeatInterval(2);
        // wait 2 seconds
        await new Promise(resolve => setTimeout(resolve, 2000));

        await statusContract.connect(user1).alive();

        const healthyV2 = await statusContract.getNodesEligibleForCommittee();
        expect(healthyV2).to.eql([nodeIdForUser1]);

    });
});
