import { ethers } from "hardhat";
import { expect } from "chai";
import { cleanDeployment } from "./fixtures";
import { Nodes } from "../typechain-types";
import { toUtf8Bytes, toUtf8String, zeroPadValue } from "ethers";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

const MOCK_IP_0 = "192.168.0.1"
const MOCK_IP_0_BYTES = toUtf8Bytes(MOCK_IP_0);

const MOCK_IP_1 = "190.168.0.1"
const MOCK_IP_1_BYTES = toUtf8Bytes(MOCK_IP_1);

chai.should();
chai.use(chaiAsPromised)

describe("Nodes", function () {
    let nodesContract: Nodes;
    let deployer: HardhatEthersSigner;
    let user1: HardhatEthersSigner;


    beforeEach(async () => {
        const {nodes} = await cleanDeployment();
        nodesContract = nodes;
        [deployer, user1] = await ethers.getSigners();
    });

    it("should register Nodes", async () => {

        await nodesContract.registerNode(MOCK_IP_0_BYTES, 8000);

        const node = await nodesContract.getNode(1);

        expect(node.id).to.equal(1n);
        expect(node.port).to.equal(8000n);
        expect(toUtf8String(node.ip)).to.equal(MOCK_IP_0);
        const emptyBytes32 = zeroPadValue("0x", 32);
        expect(node.nodePublicKey[0]).to.equal(emptyBytes32);
        expect(node.nodePublicKey[1]).to.equal(emptyBytes32);
        expect(node.nodeAddress).to.equal(deployer.address);

        await nodesContract.connect(user1).registerPassiveNode(MOCK_IP_1_BYTES, 8000);

        const passiveNode = await nodesContract.getNode(2);

        expect(passiveNode.id).to.equal(2n);
        expect(passiveNode.port).to.equal(8000n);
        expect(toUtf8String(passiveNode.ip)).to.equal(MOCK_IP_1);
        expect(passiveNode.nodePublicKey[0]).to.equal(emptyBytes32);
        expect(passiveNode.nodePublicKey[1]).to.equal(emptyBytes32);
        expect(passiveNode.nodeAddress).to.equal(user1.address);

    });

    it("should revert when nodeId or address do not exist", async () => {
        await expect(nodesContract.getNode(0))
        .to.be.revertedWithCustomError(nodesContract, "NodeDoesNotExist").withArgs(0);

        await expect(nodesContract.getNodeId(deployer))
        .to.be.revertedWithCustomError(nodesContract, "AddressIsNotAssignedToAnyNode");
    });

    it("should revert when new node is invalid", async () => {

        await nodesContract.registerPassiveNode(MOCK_IP_0_BYTES, 8000);

        // Node address is duplicate
        await expect(nodesContract.registerPassiveNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressAlreadyHasNode");
        await expect(nodesContract.registerNode(MOCK_IP_1_BYTES, 8000))
        .to.be.revertedWithCustomError(nodesContract, "AddressAlreadyHasNode");

    });

});
