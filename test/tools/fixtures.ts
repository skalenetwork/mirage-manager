// cspell:words hexlify

import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { deploy } from "../../migrations/deploy";
import { HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";
import { INodes, IDkg, Nodes, Status, Staking } from "../../typechain-types";
import { getPublicKey } from "./signatures";

// Parameters

const numberOfNodes = 50;
const initialNumberOfNodes = 22;
const nodeBalance = ethers.parseEther("1");
const nodeStake = ethers.parseEther("1");
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
            id: i,
            ip: getIp(),
            domainName: `d2-${i}.skale`,
            nodeAddress: wallet.address,
            port: 8000,
            wallet: wallet,
            publicKey: await getPublicKey(wallet)
        });
    }
    return nodesData;
}

const registerNodes = async (nodes: Nodes, nodesData: NodeData[]) => {
    for (const node of nodesData) {
        await nodes.connect(node.wallet).registerNode(node.ip, node.publicKey, node.port);
        const nodeId = await nodes.getNodeId(node.wallet.address);
        node.id = nodeId;
    }
}

const whitelistNodes = async (status: Status, nodesData: NodeData[]) => {
    for (const node of nodesData) {
        await status.whitelistNode(node.id);
    }
}

export const sendHeartbeat = async (status: Status, nodesData: NodeData[]) => {
    for (const node of nodesData) {
        await status.connect(node.wallet).alive();
    }
}

const stake = async (staking: Staking, nodesData: NodeData[]) => {
    for (const node of nodesData) {
        await staking.stake(node.id, {value: nodeStake});
    }
}

// Fixtures

const deployFixture = async () => {
    const nodesData = await generateRandomNodes(initialNumberOfNodes);
    const contracts = await deploy(nodesData, commonPublicKey);
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

const registeredOnlyNodesFixture = async () => {
    const contracts = await cleanDeployment();
    const { nodes } = contracts;
    const nodesData = await generateRandomNodes(numberOfNodes - initialNumberOfNodes);

    await registerNodes(nodes, nodesData);

    return { ...contracts, nodesData:[...contracts.nodesData, ...nodesData] };
}

const whitelistedNodesFixture = async () => {
    const registeredNodes = await registeredOnlyNodes();
    await whitelistNodes(registeredNodes.status, registeredNodes.nodesData);
    return {...registeredNodes};
}

const nodesWhitelistedAndHealthyFixture = async () => {
    const deployment = await whitelistedNodes();
    await sendHeartbeat(deployment.status, deployment.nodesData);
    return {...deployment};
}

const whitelistedAndStakedNodesFixture = async () => {
    const deployment = await whitelistedNodes();
    const { staking, nodesData } = deployment;
    await stake(staking, nodesData);
    return {...deployment};
}

const stakedNodesFixture = async () => {
    const deployment = await registeredOnlyNodes();
    const { staking, nodesData } = deployment;
    await stake(staking, nodesData);
    return {...deployment};
}

const whitelistedAndStakedAndHealthyNodesFixture = async () => {
    const deployment = await whitelistedAndStakedNodes();
    await sendHeartbeat(deployment.status, deployment.nodesData);
    return {...deployment};
}

// External functions

export const cleanDeployment = async () => loadFixture(deployFixture);
export const registeredOnlyNodes = async () => loadFixture(registeredOnlyNodesFixture);
export const stakedNodes = async () => loadFixture(stakedNodesFixture);
export const whitelistedNodes = async () => loadFixture(whitelistedNodesFixture);
export const whitelistedAndHealthyNodes = async () => loadFixture(nodesWhitelistedAndHealthyFixture);
export const whitelistedAndStakedNodes = async () => loadFixture(whitelistedAndStakedNodesFixture);
export const whitelistedAndStakedAndHealthyNodes = async () => loadFixture(whitelistedAndStakedAndHealthyNodesFixture);
