// cspell:words hexlify

import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { deploy as productionDeploy } from "../migrations/deploy";
import { HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";

// Parameters

const numberOfNodes = 50;
const nodeBalance = ethers.parseEther("1");

// Auxiliary functions

export interface NodeData {
    wallet: HDNodeWallet;
    id: bigint;
}

const getIp = (): Uint8Array => ethers.randomBytes(4);

// Fixtures

const deploy = async () => {
    const contracts = await productionDeploy();
    return {
        committee: contracts.Committee,
        dkg: contracts.DKG,
        nodes: contracts.Nodes,
        staking: contracts.Staking,
        status: contracts.Status
    }
}

const registerNodes = async () => {
    const [owner] = await ethers.getSigners();
    const contracts = await loadFixture(deploy);
    const {nodes} = contracts;
    const nodesData: NodeData[] = [];
    for (let iterator = 0; iterator < numberOfNodes; ++iterator) {
        const wallet = Wallet.createRandom().connect(ethers.provider);
        await owner.sendTransaction({
            to: wallet.address,
            value: nodeBalance
        });
        await nodes.connect(wallet).registerNode(getIp(), ethers.toBigInt("0xd2"));
        const nodeId = await nodes.getNodeId(wallet.address);
        nodesData.push({wallet, id: nodeId});
    }
    return {...contracts, nodesData};
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
