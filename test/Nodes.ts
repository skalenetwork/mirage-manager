import { ethers } from "hardhat";
import { expect } from "chai";
import { cleanDeployment, sendHeartbeat, whitelistedAndStakedNodes } from "./tools/fixtures";
import { Nodes } from "../typechain-types";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import ip from "ip";
import { BigNumberish, BytesLike, getBytes, ZeroHash } from 'ethers';
import { getPublicKey } from "./tools/signatures";

const INVALID_IPV4 = "0.0.0.0"
const INVALID_IPV4_BYTES = ip.toBuffer(INVALID_IPV4);

const INVALID_IPV6 = "0000:0000:0000:0000:0000:0000:0000:0000"
const INVALID_IPV6_BYTES = ip.toBuffer(INVALID_IPV6);

const MOCK_IP_0 = "192.168.0.1"
const MOCK_IP_0_BYTES = ip.toBuffer(MOCK_IP_0);
const MOCK_DOMAIN_NAME_0 = "skale.pt"

const MOCK_IP_1 = "190.168.0.1"
const MOCK_IP_1_BYTES = ip.toBuffer(MOCK_IP_1);
const MOCK_DOMAIN_NAME_1 = "mirage.pt"


const MOCK_IP_2 = "191.168.0.1"
const MOCK_IP_2_BYTES = ip.toBuffer(MOCK_IP_2);

const MOCK_IPV6 = "2001:0db8:85a3:0000:0000:8a2e:0370:7334";
const MOCK_IPV6_BYTES = ip.toBuffer(MOCK_IPV6);

chai.should();
chai.use(chaiAsPromised)

describe("Nodes", function () {
    let nodesContract: Nodes;
    let deployer: HardhatEthersSigner;
    let user1: HardhatEthersSigner;
    let user2: HardhatEthersSigner;
    let deployerPubKey: [BytesLike, BytesLike];
    let user1PubKey: [BytesLike, BytesLike];
    let user2PubKey: [BytesLike, BytesLike];


    beforeEach(async () => {
        const {nodes} = await cleanDeployment();
        nodesContract = nodes;
        [deployer, user1, user2] = await ethers.getSigners();

        [deployerPubKey, user1PubKey, user2PubKey] = await Promise.all(
            [deployer, user1, user2].map((user) => getPublicKey(user))
        );
    });

    it("should register Active Nodes", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);
        const nodeId = await nodesContract.getNodeId(deployer.address) as BigNumberish;
        const node = await nodesContract.getNode(nodeId);

        expect(node.id).to.equal(nodeId);
        expect(node.port).to.equal(8000n);
        expect(Buffer.from(getBytes(node.ip))).to.eql(MOCK_IP_0_BYTES);
        expect(node.nodeAddress).to.equal(deployer.address);
        expect(node.publicKey).to.eql(deployerPubKey);

        expect(await nodesContract.getNodeId(deployer.address)).to.equal(nodeId);

        expect(await nodesContract.getActiveNodeIds()).to.include(nodeId);
        expect(await nodesContract.activeNodeExists(nodeId)).to.eql(true);
        const passiveNodeIds = await nodesContract.getPassiveNodeIds();
        expect(passiveNodeIds.length).to.eql(0);

    });

    it("should register Passive Nodes", async () => {

        await nodesContract.registerPassiveNode(MOCK_IPV6_BYTES, 8000);
        const [passiveNodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);
        const passiveNode = await nodesContract.getNode(passiveNodeId);
        expect(passiveNode.id).to.equal(passiveNodeId);
        expect(passiveNode.port).to.equal(8000n);
        expect(Buffer.from(getBytes(passiveNode.ip))).to.eql(MOCK_IPV6_BYTES);
        expect(passiveNode.nodeAddress).to.equal(deployer.address);
        expect(await nodesContract.getPassiveNodeIdsForAddress(deployer.address)).to.include(passiveNodeId);

        await nodesContract.connect(user1).registerPassiveNode(MOCK_IP_2_BYTES, 8000);

        const nodesDeployer = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);
        const nodesUser1 = await nodesContract.getPassiveNodeIdsForAddress(user1.address);

        const allPassiveNodeIds = await nodesContract.getPassiveNodeIds();
        expect(nodesDeployer.length).to.eql(1);
        expect(nodesUser1.length).to.eql(1);
        expect(allPassiveNodeIds.length).to.eql(2);
        expect(allPassiveNodeIds).to.eql(nodesDeployer.concat(nodesUser1));
    });

    it("should revert when node does not exist", async () => {
        await expect(nodesContract.getNode(0))
        .to.be.reverted;

        await expect(nodesContract.getNodeId(deployer.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode");

        await expect(nodesContract.getPassiveNodeIdsForAddress(deployer.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode");
    });

    it("should revert when active node does not exist", async () => {

        await expect(nodesContract.getNodeId(deployer))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode");

        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);

        await expect(nodesContract.getNodeId(deployer))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode");

    });


    it("should validate node input while registering", async () => {

        await expect(nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 0))
        .to.be.reverted;

        await expect(nodesContract.registerPassiveNode(INVALID_IPV4_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

        await expect(nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 0))
        .to.be.reverted;

        await expect(nodesContract.registerNode(INVALID_IPV6_BYTES, deployerPubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

        await expect(nodesContract.registerNode(MOCK_IPV6_BYTES, [ZeroHash, ZeroHash], 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidPublicKey");

    });
    it("should block registration of duplicates", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);

        // Node address is taken by active node
        await expect(nodesContract.registerPassiveNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, deployerPubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

        // IP address is taken by active node
        await expect(nodesContract.connect(user1).registerPassiveNode(MOCK_IP_0_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");
        await expect(nodesContract.connect(user1).registerNode(MOCK_IP_0_BYTES, user1PubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");

        // New passive node
        await nodesContract.connect(user1).registerPassiveNode(MOCK_IP_1_BYTES, 8000)

        // Node Address is assigned to passive nodes
        await expect(nodesContract.connect(user1).registerNode(MOCK_IP_2_BYTES, user1PubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");

        // IP Address is assigned to passive node
        await expect(nodesContract.connect(user2).registerNode(MOCK_IP_1_BYTES, user2PubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");
    });


    it("should allow only Node owner to change IP and Domain Name", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);

        const nodeId = await nodesContract.getNodeId(deployer.address) as BigNumberish;
        const node_v1 = await nodesContract.getNode(nodeId);

        expect(Buffer.from(getBytes(node_v1.ip))).to.eql(MOCK_IP_0_BYTES);
        expect(node_v1.domainName).to.equal("");

        await nodesContract.setDomainName(nodeId, MOCK_DOMAIN_NAME_1);
        await nodesContract.setIpAddress(nodeId, MOCK_IP_1_BYTES, 8000);

        const node_v2 = await nodesContract.getNode(nodeId);

        expect(Buffer.from(getBytes(node_v2.ip))).to.eql(MOCK_IP_1_BYTES);
        expect(node_v2.domainName).to.equal(MOCK_DOMAIN_NAME_1);

        await expect(nodesContract.connect(user1).setDomainName(nodeId, MOCK_DOMAIN_NAME_1))
        .to.be.reverted;
        await expect(nodesContract.connect(user1).setIpAddress(nodeId, MOCK_IP_1_BYTES, 8000))
        .to.be.reverted;

        await nodesContract.setDomainName(nodeId, MOCK_DOMAIN_NAME_0);

        const node_v3 = await nodesContract.getNode(nodeId);
        expect(node_v3.domainName).to.equal(MOCK_DOMAIN_NAME_0);

    });

    it("should block duplicate domain names ", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);
        const firstRegisteredNodeId = await nodesContract.getNodeId(deployer.address) as BigNumberish;

        await nodesContract.setDomainName(firstRegisteredNodeId, MOCK_DOMAIN_NAME_1);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, user1PubKey, 8000);
        const secondRegisteredNodeId = await nodesContract.getNodeId(user1.address) as BigNumberish;

        await expect(nodesContract.connect(user1).setDomainName(secondRegisteredNodeId, MOCK_DOMAIN_NAME_1))
        .to.be.revertedWithCustomError(nodesContract, "DomainNameAlreadyTaken");

    });

    it("should block invalid IP address change requests", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);
        const nodeId = await nodesContract.getNodeId(deployer.address);
        const nonExistentNodeId = 9999;

        await expect(nodesContract.setIpAddress(nonExistentNodeId, MOCK_IP_1_BYTES, 8000))
        .to.be.reverted;

        await expect(nodesContract.setIpAddress(nodeId, INVALID_IPV4_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

        await expect(nodesContract.setIpAddress(nodeId, "0x09", 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

        await expect(nodesContract.setIpAddress(nodeId, MOCK_IP_1_BYTES, 0))
        .to.be.reverted;

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, user1PubKey, 8000);

        await expect(nodesContract.setIpAddress(nodeId, MOCK_IP_1_BYTES, 9000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");
    });

    it("should not allow submit address change requests for not existent nodes", async () => {
        const nonExistentNodeId = 9999;
        await expect(nodesContract.requestChangeOwner(nonExistentNodeId, deployer.address))
        .to.be.reverted;
    });

    it("should not allow active nodes to change owner", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);
        const nodeId = await nodesContract.getNodeId(deployer.address);

        expect(nodesContract.requestChangeOwner(nodeId, user1.address))
        .to.be.revertedWithCustomError(nodesContract, "ActiveNodesCannotChangeOwnership");
    })

    it("should allow only Node owner to request Node address change", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        const [nodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        await expect(nodesContract.connect(user1).requestChangeOwner(nodeId, user1.address))
        .to.be.reverted;

        await nodesContract.requestChangeOwner(nodeId, user1.address);

        expect(await nodesContract.ownerChangeRequests(nodeId)).to.eql(user1.address);
    });

    it("should not allow passive nodes to request active node's addresses", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        const [firstNodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, user1PubKey, 8000);

        await expect(nodesContract.requestChangeOwner(firstNodeId, user1.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");
    });

    it("should allow only new Node owner to submit Node address change", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        const [nodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        await nodesContract.requestChangeOwner(nodeId, user1.address);

        await expect(nodesContract.confirmOwnerChange(nodeId))
        .to.be.reverted;

        await nodesContract.connect(user1).confirmOwnerChange(nodeId);
        const node = await nodesContract.getNode(nodeId);
        expect(node.nodeAddress).to.equal(user1.address);
    });

    it("should free an address after no passive node has it", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        const [nodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        await nodesContract.requestChangeOwner(nodeId, user1.address);

        // Fails, passive node is still owned by deployer
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, deployerPubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");

        await nodesContract.connect(user1).confirmOwnerChange(nodeId);
        const node = await nodesContract.getNode(nodeId);
        expect(node.nodeAddress).to.equal(user1.address);

        // Now it should work, deployer does not own any nodes
        await nodesContract.registerNode(MOCK_IP_1_BYTES, deployerPubKey, 8000);
        const newlyRegisteredNodeId = await nodesContract.getNodeId(deployer.address);
        await nodesContract.getNode(nodeId);
        await nodesContract.getNode(newlyRegisteredNodeId);

    });

    it("should block address change confirmation if address is taken", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        const [nodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        await nodesContract.requestChangeOwner(nodeId, user1.address);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, user1PubKey, 8000);

        await expect(nodesContract.connect(user1).confirmOwnerChange(nodeId))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

        const node = await nodesContract.getNode(nodeId);
        expect(node.nodeAddress).to.equal(deployer.address);
    });

    it("should not allow to confirm an inexistent change request (address(0))", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, deployerPubKey, 8000);
        const nodeId = await nodesContract.getNodeId(deployer.address) as BigNumberish;

        await expect(nodesContract.confirmOwnerChange(nodeId))
        .to.be.reverted;

        const node = await nodesContract.getNode(nodeId);
        expect(node.nodeAddress).to.equal(deployer.address);

    });

    it("should free old address ONLY if 0 passive nodes have it.", async () => {
        // deployer owns 2 passive nodes
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        await nodesContract.registerPassiveNode(MOCK_IP_1_BYTES, 8000);
        const [firstNodeId, secondNodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        // Fails, active node addresses must be unique
        await expect(nodesContract.registerNode(MOCK_IP_2_BYTES, deployerPubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");


        await nodesContract.requestChangeOwner(firstNodeId, user1.address);
        await nodesContract.connect(user1).confirmOwnerChange(firstNodeId);
        const node = await nodesContract.getNode(firstNodeId);
        expect(node.nodeAddress).to.equal(user1.address);

        // Fails, deployer still owns 1 passive node
        await expect(nodesContract.registerNode(MOCK_IP_2_BYTES, deployerPubKey, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");

        await nodesContract.requestChangeOwner(secondNodeId, user2.address);
        await nodesContract.connect(user2).confirmOwnerChange(secondNodeId);
        const node2 = await nodesContract.getNode(secondNodeId);
        expect(node2.nodeAddress).to.equal(user2.address);

        // Now deployer should be free
        await nodesContract.registerNode(MOCK_IP_2_BYTES, deployerPubKey, 8000);
        const activeNodeId = await nodesContract.getNodeId(deployer.address);

        const node3 = await nodesContract.getNode(activeNodeId);
        expect(node3.nodeAddress).to.equal(deployer.address);

    });

    it("should revert when passive node was already assigned to the new address", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        const [firstNodeId] = await nodesContract.getPassiveNodeIdsForAddress(deployer.address);

        await nodesContract.requestChangeOwner(firstNodeId, deployer.address);

        await expect(nodesContract.confirmOwnerChange(firstNodeId))
        .to.be.revertedWithCustomError(nodesContract, "PassiveNodeAlreadyExistsForAddress");
    });

    it("should should not allow changing nodes data if node in current or next committee", async () => {
        const {committee, nodesData, nodes, status} = await whitelistedAndStakedNodes();
        await committee.setCommitteeSize(5); // to save resources
        await sendHeartbeat(status, nodesData.slice(0, 10)); // to save time
        await committee.select();

        for(const node of nodesData) {
            const newIp = ethers.randomBytes(4);
            const nodeBlocked = await committee.isNodeInCurrentOrNextCommittee(node.id);
            if (nodeBlocked) {
                expect(nodes.connect(node.wallet).setIpAddress(node.id, newIp, 8000))
                .to.be.revertedWithCustomError(nodes, "NodeIsInCommittee");
            }
            else {
                await nodes.connect(node.wallet).setIpAddress(node.id, newIp, 8000);
                expect(Buffer.from(getBytes((await nodes.getNode(node.id)).ip))).to.eql(newIp);
            }
        }

    });

});
