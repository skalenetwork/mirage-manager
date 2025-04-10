// cspell:words hexlify

import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { deploy as productionDeploy } from "../migrations/deploy";
import { BigNumberish, HDNodeWallet, Wallet } from "ethers";
import { ethers } from "hardhat";

// Parameters

const numberOfNodes = 50;
const nodeBalance = ethers.parseEther("1");

// Auxiliary functions

export interface NodeData {
    wallet: HDNodeWallet;
    id: bigint;
}

const getIp = (i: BigNumberish) => ethers.getBytes(
    ethers.concat([
        ethers.hexlify("0xd2d2d2"),
        ethers.toBeHex(i)
    ])
);

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
    for (let nodeId = 1n; nodeId <= numberOfNodes; ++nodeId) {
        const wallet = Wallet.createRandom().connect(ethers.provider);
        await owner.sendTransaction({
            to: wallet.address,
            value: nodeBalance
        });
        await nodes.connect(wallet).registerNode(getIp(nodeId), ethers.toBigInt("0xd2"));
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
