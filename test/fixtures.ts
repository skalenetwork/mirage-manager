// cspell:words hexlify

import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { deploy as productionDeploy } from "../migrations/deploy";
import { HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";
import { INodes, IDkg } from "../typechain-types";

// Parameters

const numberOfNodes = 50;
const initialNumberOfNodes = 22;
const nodeBalance = ethers.parseEther("1");
export const commonPublicKey: IDkg.G2PointStruct = {
    x: {
      a: 1344029448544809206912243137223916831397685297347960966147194066834973842416n,
      b: 14009188865893419053765068430734613618138420480441352606222177863861567518758n,
    },
    y: {
      a: 10690960156228072079001083521941886387682522891194608928128426154732026520769n,
      b: 9828205031595443956611906871964866113822094147752101207883765686014961818260n,
    },
  };

// Auxiliary functions

export interface NodeData {
    wallet: HDNodeWallet;
    id: bigint;
}

const getIp = (): Uint8Array => ethers.randomBytes(4);

// Fixtures

const deploy = async () => {
    const nodeList = await generateRandomNodes(initialNumberOfNodes);
    const contracts = await productionDeploy(nodeList, commonPublicKey);
    return {
        committee: contracts.Committee,
        dkg: contracts.DKG,
        nodes: contracts.Nodes,
        staking: contracts.Staking,
        status: contracts.Status
    }
}

const generateRandomNodes = async (initialNumberOfNodes?: number) => {
    initialNumberOfNodes = initialNumberOfNodes || numberOfNodes;
    const nodeList: INodes.NodeStruct[] = [];
    for (let i = 0; i < initialNumberOfNodes; ++i) {
        const wallet = Wallet.createRandom().connect(ethers.provider) as HDNodeWallet;
        const ip = getIp();
        const domainName = "d2" + i + ".skale";
        const port = "8000";
        nodeList.push({
            id: 0,
            ip,
            domainName,
            nodeAddress: wallet.address,
            port
        });
    }
    return nodeList;
}

const registerNodes = async () => {
    const [owner] = await ethers.getSigners();
    const contracts = await loadFixture(deploy);
    const { nodes } = contracts;
    const nodesData: NodeData[] = [];
    const nodeList = await generateRandomNodes();

    for (const node of nodeList) {
        const wallet = Wallet.createRandom().connect(ethers.provider) as HDNodeWallet;
        await owner.sendTransaction({
            to: wallet.address,
            value: nodeBalance
        });
        await nodes.connect(wallet).registerNode(node.ip, node.port);
        const nodeId = await nodes.getNodeId(wallet.address);
        nodesData.push({ wallet, id: nodeId });
    }
    return { ...contracts, nodesData };
}

const whitelistNodes = async () => {
    const registeredNodes = await nodesRegisteredButNotWhitelisted();
    for (const node of registeredNodes.nodesData) {
        await registeredNodes.status.whitelistNode(node.id);
    }
    return {...registeredNodes};
}

const registerNodesAndSendHeartbeat = async () => {
    const registeredNodes = await nodesRegistered();
    for (const node of registeredNodes.nodesData) {
        await registeredNodes.status.connect(node.wallet).alive();
    }
    return {...registeredNodes};
}

// External functions

export const cleanDeployment = async () => loadFixture(deploy);
export const nodesRegisteredButNotWhitelisted = async () => loadFixture(registerNodes);
export const nodesRegistered = async () => loadFixture(whitelistNodes);
export const nodesAreRegisteredAndHeartbeatIsSent = async () => loadFixture(registerNodesAndSendHeartbeat);
