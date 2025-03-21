import { ethers } from "hardhat";
import { expect } from "chai";
import { cleanDeployment } from "./fixtures";
import { Nodes } from "../typechain-types";
import { toUtf8Bytes, toUtf8String, zeroPadValue } from "ethers";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";

const MOCK_IP = "192.168.0.1"
const MOCK_IP_BYTES = toUtf8Bytes(MOCK_IP);

chai.should();
chai.use(chaiAsPromised)

describe("Nodes", function () {
    let nodesContract: Nodes;
    beforeEach(async () => {
        const {nodes} = await cleanDeployment();
        nodesContract = nodes;
    });

    it("should register Active Node", async () => {

        await nodesContract.registerNode(MOCK_IP_BYTES, 8000);

        const node = await nodesContract.getNode(0);

        expect(node.id).to.equal(0n);
        expect(node.port).to.equal(8000n);
        expect(toUtf8String(node.ip)).to.equal(MOCK_IP);
        const emptyBytes32 = zeroPadValue("0x", 32);
        expect(node.nodePublicKey[0]).to.equal(emptyBytes32)
        expect(node.nodePublicKey[1]).to.equal(emptyBytes32)

    });

    it("should register Passive Node", async () => {

        await nodesContract.registerPassiveNode(MOCK_IP_BYTES, 8000);

        const node = await nodesContract.getNode(0);

        expect(node.id).to.equal(0n);
        expect(node.port).to.equal(8000n);
        expect(toUtf8String(node.ip)).to.equal(MOCK_IP);
        const emptyBytes32 = zeroPadValue("0x", 32);
        expect(node.nodePublicKey[0]).to.equal(emptyBytes32)
        expect(node.nodePublicKey[1]).to.equal(emptyBytes32)

    });

    it("should revert when nodeId does not exist", async () => {
        await expect(nodesContract.getNode(0))
        .to.be.revertedWithCustomError(nodesContract, "NodeDoesNotExist").withArgs(0);
    })
});
