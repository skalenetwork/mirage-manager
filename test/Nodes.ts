import { ethers } from "hardhat";
import { expect } from "chai";
import { cleanDeployment } from "./fixtures";
import { Nodes } from "../typechain-types";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { bytesToIpv4String, ipv4StringToBytes } from "./utils";

const INVALID_IP_0 = "0.0.0.0"
const INVALID_IP_0_BYTES = ipv4StringToBytes(INVALID_IP_0);

const MOCK_IP_0 = "192.168.0.1"
const MOCK_IP_0_BYTES = ipv4StringToBytes(MOCK_IP_0);
//const MOCK_DOMAIN_NAME_0 = "playa.com"

const MOCK_IP_1 = "190.168.0.1"
const MOCK_IP_1_BYTES = ipv4StringToBytes(MOCK_IP_1);
const MOCK_DOMAIN_NAME_1 = "playa.pt"


const MOCK_IP_2 = "191.168.0.1"
const MOCK_IP_2_BYTES = ipv4StringToBytes(MOCK_IP_2);
//const MOCK_DOMAIN_NAME_2 = "playa.ua"


chai.should();
chai.use(chaiAsPromised)

describe("Nodes", function () {
    let nodesContract: Nodes;
    let deployer: HardhatEthersSigner;
    let user1: HardhatEthersSigner;
    let user2: HardhatEthersSigner;

    beforeEach(async () => {
        const {nodes} = await cleanDeployment();
        nodesContract = nodes;
        [deployer, user1, user2] = await ethers.getSigners();
    });

    it("should register Nodes", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        const node = await nodesContract.getNode(1);
        expect(node.id).to.equal(1n);
        expect(node.port).to.equal(8000n);
        expect(bytesToIpv4String(node.ip)).to.equal(MOCK_IP_0);
        expect(node.nodeAddress).to.equal(deployer.address);

        await nodesContract.connect(user1).registerPassiveNode(MOCK_IP_1_BYTES, 8000);

        const passiveNode = await nodesContract.getNode(2);

        expect(passiveNode.id).to.equal(2n);
        expect(passiveNode.port).to.equal(8000n);
        expect(bytesToIpv4String(passiveNode.ip)).to.equal(MOCK_IP_1);
        expect(passiveNode.nodeAddress).to.equal(user1.address);

    });

    it("should revert when node does not exist", async () => {
        await expect(nodesContract.getNode(0))
        .to.be.revertedWithCustomError(nodesContract, "NodeDoesNotExist").withArgs(0);

        await expect(nodesContract.getNodeId(deployer))
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
        .to.be.revertedWithCustomError(nodesContract, "InvalidPortNumber");

        await expect(nodesContract.registerPassiveNode(INVALID_IP_0_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

    });
    it("should block registration of duplicates", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        // Node address is taken by active node
        await expect(nodesContract.registerPassiveNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressAlreadyHasNode");
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressAlreadyHasNode");

        // IP address is taken by active node
        await expect(nodesContract.connect(user1).registerPassiveNode(MOCK_IP_0_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");
        await expect(nodesContract.connect(user1).registerNode(MOCK_IP_0_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");

        // New passive node
        await nodesContract.connect(user1).registerPassiveNode(MOCK_IP_1_BYTES, 8000)

        // Node Address is assigned to passive nodes
        await expect(nodesContract.connect(user1).registerNode(MOCK_IP_2_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");

        // IP Address is assigned to passive node
        await expect(nodesContract.connect(user2).registerNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");
    });


    it("should allow only Node owner to change IP and Domain Name", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        const node_v1 = await nodesContract.getNode(1);

        expect(bytesToIpv4String(node_v1.ip)).to.equal(MOCK_IP_0);
        expect(node_v1.domainName).to.equal("");

        await nodesContract.setDomainName(1, MOCK_DOMAIN_NAME_1);
        await nodesContract.setIpAddress(1, MOCK_IP_1_BYTES, 8000);

        const node_v2 = await nodesContract.getNode(1);

        expect(bytesToIpv4String(node_v2.ip)).to.equal(MOCK_IP_1);
        expect(node_v2.domainName).to.equal(MOCK_DOMAIN_NAME_1);

        await expect(nodesContract.connect(user1).setDomainName(1, MOCK_DOMAIN_NAME_1))
        .to.be.revertedWithCustomError(nodesContract, "InvalidSender");
        await expect(nodesContract.connect(user1).setIpAddress(1, MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidSender");
    });

    it("should allow only Node owner to request Node address change", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await expect(nodesContract.connect(user1).requestChangeAddress(1, user1.address))
        .to.be.revertedWithCustomError(nodesContract, "InvalidSender");

        await nodesContract.requestChangeAddress(1, user1.address);

        expect(await nodesContract.addressChangeRequests(1)).to.equal(user1.address);

    });

    it("should allow only new Node owner to submit Node address change", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.requestChangeAddress(1, user1.address);

        await expect(nodesContract.confirmAddressChange(1))
        .to.be.revertedWithCustomError(nodesContract, "InvalidSender");

        await nodesContract.connect(user1).confirmAddressChange(1);
        const node = await nodesContract.getNode(1);
        expect(node.nodeAddress).to.equal(user1.address);
    });

    it("should free old address after change is successful", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.requestChangeAddress(1, user1.address);

        // Fails, request not made yet
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressAlreadyHasNode");

        await nodesContract.connect(user1).confirmAddressChange(1);
        const node = await nodesContract.getNode(1);
        expect(node.nodeAddress).to.equal(user1.address);

        // Now it should work
        await nodesContract.registerNode(MOCK_IP_1_BYTES, 8000);
        await nodesContract.getNode(1);
        await nodesContract.getNode(2);

    });

    it("should block address change confirmation if address is taken", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.requestChangeAddress(1, user1.address);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);

        await expect(nodesContract.connect(user1).confirmAddressChange(1))
        .to.be.revertedWithCustomError(nodesContract, "AddressAlreadyHasNode");

        const node = await nodesContract.getNode(1);
        expect(node.nodeAddress).to.equal(deployer.address);

    });

    it("should free old address ONLY if 0 passive nodes have it.", async () => {
        // deployer owns 2 passive nodes
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);
        await nodesContract.registerPassiveNode(MOCK_IP_1_BYTES, 8000);

        // Fails, active node addresses must be unique
        await expect(nodesContract.registerNode(MOCK_IP_2_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");


        await nodesContract.requestChangeAddress(1, user1.address);
        await nodesContract.connect(user1).confirmAddressChange(1);
        const node = await nodesContract.getNode(1);
        expect(node.nodeAddress).to.equal(user1.address);

        // Fails, deployer still owns 1 passive node
        await expect(nodesContract.registerNode(MOCK_IP_2_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");

        await nodesContract.requestChangeAddress(2, user2.address);
        await nodesContract.connect(user2).confirmAddressChange(2);
        const node2 = await nodesContract.getNode(2);
        expect(node2.nodeAddress).to.equal(user2.address);


        // Now deployer should be free
        await nodesContract.registerNode(MOCK_IP_2_BYTES, 8000);

        const node3 = await nodesContract.getNode(3);
        expect(node3.nodeAddress).to.equal(deployer.address);

    });

});
