import { ethers } from "hardhat";
import { expect } from "chai";
import { cleanDeployment } from "./fixtures";
import { Nodes } from "../typechain-types";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import ip from "ip";
import { getBytes } from 'ethers';


const INVALID_IPV4 = "0.0.0.0"
const INVALID_IPV4_BYTES = ip.toBuffer(INVALID_IPV4);

const INVALID_IPV6 = "0000:0000:0000:0000:0000:0000:0000:0000"
const INVALID_IPV6_BYTES = ip.toBuffer(INVALID_IPV6);

const MOCK_IP_0 = "192.168.0.1"
const MOCK_IP_0_BYTES = ip.toBuffer(MOCK_IP_0);
const MOCK_DOMAIN_NAME_0 = "skale.pt"

const MOCK_IP_1 = "190.168.0.1"
const MOCK_IP_1_BYTES = ip.toBuffer(MOCK_IP_1);
const MOCK_DOMAIN_NAME_1 = "playa.pt"


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

    beforeEach(async () => {
        const {nodes} = await cleanDeployment();
        nodesContract = nodes;
        [deployer, user1, user2] = await ethers.getSigners();
    });

    it("should register Active Nodes", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        const node = await nodesContract.getNode(1);
        expect(node.id).to.equal(1n);
        expect(node.port).to.equal(8000n);
        expect(Buffer.from(getBytes(node.ip))).to.eql(MOCK_IP_0_BYTES);
        expect(node.nodeAddress).to.equal(deployer.address);

        expect(await nodesContract.getNodeId(deployer.address)).to.equal(1n);

        expect(await nodesContract.getActiveNodesIds()).to.eql([1n]);
    });

    it("should register Passive Nodes", async () => {

        await nodesContract.registerPassiveNode(MOCK_IPV6_BYTES, 8000);

        const passiveNode = await nodesContract.getNode(1);

        expect(passiveNode.id).to.equal(1n);
        expect(passiveNode.port).to.equal(8000n);
        expect(Buffer.from(getBytes(passiveNode.ip))).to.eql(MOCK_IPV6_BYTES);
        expect(passiveNode.nodeAddress).to.equal(deployer.address);
        expect(await nodesContract.getPassiveNodeIds(deployer.address)).to.eql([1n])
    });

    it("should revert when node does not exist", async () => {
        await expect(nodesContract.getNode(0))
        .to.be.reverted;

        await expect(nodesContract.getNodeId(deployer.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode");

        await expect(nodesContract.getPassiveNodeIds(deployer.address))
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

        await expect(nodesContract.registerNode(MOCK_IP_0_BYTES, 0))
        .to.be.reverted;

        await expect(nodesContract.registerNode(INVALID_IPV6_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

    });
    it("should block registration of duplicates", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        // Node address is taken by active node
        await expect(nodesContract.registerPassiveNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

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

        expect(Buffer.from(getBytes(node_v1.ip))).to.eql(MOCK_IP_0_BYTES);
        expect(node_v1.domainName).to.equal("");

        await nodesContract.setDomainName(1, MOCK_DOMAIN_NAME_1);
        await nodesContract.setIpAddress(1, MOCK_IP_1_BYTES, 8000);

        const node_v2 = await nodesContract.getNode(1);

        expect(Buffer.from(getBytes(node_v2.ip))).to.eql(MOCK_IP_1_BYTES);
        expect(node_v2.domainName).to.equal(MOCK_DOMAIN_NAME_1);

        await expect(nodesContract.connect(user1).setDomainName(1, MOCK_DOMAIN_NAME_1))
        .to.be.reverted;
        await expect(nodesContract.connect(user1).setIpAddress(1, MOCK_IP_1_BYTES, 8000))
        .to.be.reverted;

        await nodesContract.setDomainName(1, MOCK_DOMAIN_NAME_0);

        const node_v3 = await nodesContract.getNode(1);
        expect(node_v3.domainName).to.equal(MOCK_DOMAIN_NAME_0);

    });

    it("should block duplicate domain names ", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.setDomainName(1, MOCK_DOMAIN_NAME_1);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);

        await expect(nodesContract.connect(user1).setDomainName(3, MOCK_DOMAIN_NAME_1))
        .to.be.reverted;

        await expect(nodesContract.connect(user1).setDomainName(2, MOCK_DOMAIN_NAME_1))
        .to.be.revertedWithCustomError(nodesContract, "DomainNameAlreadyTaken");

    });

    it("should block invalid IP address change requests", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await expect(nodesContract.setIpAddress(2, MOCK_IP_1_BYTES, 8000))
        .to.be.reverted;

        await expect(nodesContract.setIpAddress(1, INVALID_IPV4_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

        await expect(nodesContract.setIpAddress(1, "0x09", 8000))
        .to.be.revertedWithCustomError(nodesContract, "InvalidIp");

        await expect(nodesContract.setIpAddress(1, MOCK_IP_1_BYTES, 0))
        .to.be.reverted;

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);

        await expect(nodesContract.setIpAddress(1, MOCK_IP_1_BYTES, 9000))
        .to.be.revertedWithCustomError(nodesContract, "IpIsNotAvailable");

    });

    it("should not allow submit address change requests for not existent nodes", async () => {
        await expect(nodesContract.requestChangeAddress(1, deployer.address))
        .to.be.reverted;
    });


    it("should allow only Node owner to request Node address change", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await expect(nodesContract.connect(user1).requestChangeAddress(1, user1.address))
        .to.be.reverted;

        await nodesContract.requestChangeAddress(1, user1.address);

        expect(await nodesContract.addressChangeRequests(1)).to.equal(user1.address);

    });

    it("should not allow passive nodes to request active node's addresses", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);


        await expect(nodesContract.requestChangeAddress(1, user1.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

    });

    it("should not allow active nodes to request passive node's addresses", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);


        await expect(nodesContract.connect(user1).requestChangeAddress(2, deployer.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressInUseByPassiveNodes");

    });

    it("should not allow active nodes to request active node's addresses", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);

        await expect(nodesContract.connect(user1).requestChangeAddress(2, deployer.address))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

    });

    it("should allow only new Node owner to submit Node address change", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.requestChangeAddress(1, user1.address);

        await expect(nodesContract.confirmAddressChange(1))
        .to.be.reverted;

        await nodesContract.connect(user1).confirmAddressChange(1);
        const node = await nodesContract.getNode(1);
        expect(node.nodeAddress).to.equal(user1.address);
    });

    it("should free old address after change is successful", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.requestChangeAddress(1, user1.address);

        // Fails, request not made yet
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

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
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

        const node = await nodesContract.getNode(1);
        expect(node.nodeAddress).to.equal(deployer.address);

    });

    it("should not allow address(0)", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await expect(nodesContract.confirmAddressChange(1))
        .to.be.reverted;

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

    it("should not allow two nodes to request the same address and then confirm it", async () => {
        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        await nodesContract.connect(user1).registerNode(MOCK_IP_1_BYTES, 8000);

        await nodesContract.requestChangeAddress(1, user2.address);

        await nodesContract.connect(user1).requestChangeAddress(2, user2.address);

        const address1 = await nodesContract.addressChangeRequests(1);
        const address2 = await nodesContract.addressChangeRequests(2);
        // two nodes requested the same address
        expect(address1).to.equal(address2);

        // Node 1 gets new address successfully
        await nodesContract.connect(user2).confirmAddressChange(1);

        // Should fail to confirm the next change
        await expect(nodesContract.connect(user2).confirmAddressChange(2))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsAlreadyAssignedToNode");

    });

    it("should revert when passive node was already assigned to the new address", async () => {
        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);


        await nodesContract.requestChangeAddress(1, deployer.address);

        await expect(nodesContract.confirmAddressChange(1))
        .to.be.revertedWithCustomError(nodesContract, "PassiveNodeAlreadyExistsForAddress");

    });

    it("should should not allow changing nodes if node in committee", async () => {
        //TODO: depends on committee implementation
    });

});
