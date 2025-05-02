// cspell:words hexlify

import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { deploy as productionDeploy } from "../../migrations/deploy";
import { HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";
import { INodes, IDkg } from "../../typechain-types";

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

export interface NodeData extends INodes.NodeStruct {
    wallet: HDNodeWallet;
}

const getIp = (): Uint8Array => ethers.randomBytes(4);

// Fixtures

const deploy = async () => {
    const nodesData = await generateRandomNodes(initialNumberOfNodes);
    const contracts = await productionDeploy(nodesData, commonPublicKey);
    for (const node of nodesData) {
        node.id = await contracts.Nodes.getNodeId(node.wallet.address);
    };
    return {
        committee: contracts.Committee,
        dkg: contracts.DKG,
        nodes: contracts.Nodes,
        staking: contracts.Staking,
        status: contracts.Status,
        nodesData
    }
}

const generateRandomNodes = async (initialNumberOfNodes?: number) => {
    const [owner] = await ethers.getSigners();
    initialNumberOfNodes = initialNumberOfNodes || numberOfNodes;
    const nodesData: NodeData[] = [];
    for (let i = 0; i < initialNumberOfNodes; ++i) {
        const wallet = Wallet.createRandom().connect(ethers.provider) as HDNodeWallet;
        await owner.sendTransaction({
            to: wallet.address,
            value: nodeBalance
        });
        nodesData.push({
            id: 0,
            ip: getIp(),
            domainName: `d2-${i}.skale`,
            nodeAddress: wallet.address,
            port: 8000,
            wallet
        });
    }
    return nodesData;
}

const registerNodes = async () => {
    const contracts = await loadFixture(deploy);
    const { nodes } = contracts;
    const nodesData = await generateRandomNodes(numberOfNodes - initialNumberOfNodes);

    for (const node of nodesData) {
        await nodes.connect(node.wallet).registerNode(node.ip, node.port);
        const nodeId = await nodes.getNodeId(node.wallet.address);
        node.id = nodeId;
    }
    return { ...contracts, nodesData:[...contracts.nodesData, ...nodesData] };
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
