import chalk from "chalk";
import { ethers, network, upgrades } from "hardhat";
import { promises as fs } from 'fs';
import {
    getVersion
} from '@skalenetwork/upgrade-tools';
import { Committee, DKG, INodes, Nodes, PlayaAccessManager, Staking, Status } from "../typechain-types";
import { AddressLike } from "ethers";
import { skaleContracts } from "@skalenetwork/skale-contracts-ethers-v6";
import { SchainsInternalContract, NodesContract, KeyStorageContract } from "./types/contracts";


export const contracts = [
    "Committee",
    "DKG",
    "Nodes",
    "PlayaAccessManager",
    "Status",
    "Staking"
];

interface DeployedContracts {
    Committee: Committee,
    DKG: DKG,
    Nodes: Nodes,
    PlayaAccessManager: PlayaAccessManager,
    Staking: Staking,
    Status: Status
}

function getEnvVar(name: string, errorMessage: string): string {
    const value = process.env[name];
    if (!value) {
        console.log(chalk.red(errorMessage));
        process.exit(1);
    }
    return value;
}

async function getSkaleManagerInstance() {
    const target = getEnvVar("TARGET", "Specify desired skale-manager instance. Set 'TARGET' env var.");
    const mainnetEndpoint = getEnvVar("MAINNET_ENDPOINT", "Set 'MAINNET_ENDPOINT' environment variable.");
    const mainnetProvider = new ethers.JsonRpcProvider(mainnetEndpoint);
    const network = await skaleContracts.getNetworkByProvider(mainnetProvider);
    const project = network.getProject("skale-manager");
    return await project.getInstance(target);
}

async function fetchNodes() {
    const playaChainHash = getEnvVar("PLAYA_CHAIN_HASH", "Set 'PLAYA_CHAIN_HASH' environment variable.");
    const skaleManagerInstance = await getSkaleManagerInstance();
    const nodes = await skaleManagerInstance.getContract("Nodes") as NodesContract;
    const schainsInternal = await skaleManagerInstance.getContract("SchainsInternal") as SchainsInternalContract;
    const nodesInGroup = await schainsInternal.getNodesInGroup(playaChainHash);
    const nodeList: INodes.NodeStruct[] = [];
    for (const nodeId of nodesInGroup) {
        const [ip, domainName ,nodeAddress, port] = await Promise.all([
            nodes.getNodeIP(nodeId),
            nodes.getNodeDomainName(nodeId),
            nodes.getNodeAddress(nodeId),
            nodes.getNodePort(nodeId)
        ]);
        nodeList.push({
            id: 0,
            ip,
            domainName,
            nodeAddress,
            port
        });
    }
    return nodeList;
}

async function fetchDkgCommonPublicKey() {
    const playaChainHash = getEnvVar("PLAYA_CHAIN_HASH", "Set 'PLAYA_CHAIN_HASH' environment variable.");
    const skaleManagerInstance = await getSkaleManagerInstance();
    const dkg = await skaleManagerInstance.getContract("KeyStorage") as KeyStorageContract;
    const commonPublicKey = await dkg.getCommonPublicKey(playaChainHash);
    return commonPublicKey;
}

export const deploy = async (): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    const deployedContracts: DeployedContracts = {} as DeployedContracts;
    const nodeList = await fetchNodes();
    const commonPubilicKey = await fetchDkgCommonPublicKey();

    deployedContracts.PlayaAccessManager = await deployPlayaAccessManager(deployer);
    deployedContracts.Nodes = await deployNodes(
        deployedContracts.PlayaAccessManager,
        nodeList
    );
    deployedContracts.Committee = await deployCommittee(
        deployedContracts.PlayaAccessManager,
        deployedContracts.Nodes,
        commonPubilicKey
    );
    deployedContracts.DKG = await deployDkg(
        deployedContracts.PlayaAccessManager,
        deployedContracts.Committee,
        deployedContracts.Nodes
    );
    deployedContracts.Status = await deployStatus(
        deployedContracts.PlayaAccessManager,
        deployedContracts.Nodes
    );
    deployedContracts.Staking = await deployStaking(
        deployedContracts.PlayaAccessManager
    );

    let response = await deployedContracts.Committee.setDkg(deployedContracts.DKG);
    await response.wait();
    response = await deployedContracts.Committee.setNodes(deployedContracts.Nodes);
    await response.wait();
    response = await deployedContracts.Committee.setStatus(deployedContracts.Status);
    await response.wait();
    response = await deployedContracts.Nodes.setCommittee(deployedContracts.Committee);
    await response.wait();

    return deployedContracts;
}

const deployContract = async (name: string, args: unknown[]) => {
    const factory = await ethers.getContractFactory(name);
    const instance = await upgrades.deployProxy(
        factory,
        args
    );
    await instance.waitForDeployment();
    return instance;
}

const deployPlayaAccessManager = async (
    owner: AddressLike
): Promise<PlayaAccessManager> => {
    return await deployContract(
        "PlayaAccessManager",
        [await ethers.resolveAddress(owner)]
    ) as PlayaAccessManager;
}

const deployCommittee = async (
    authority: PlayaAccessManager,
    nodes: Nodes,
    commonPubilicKey: [string, string, string, string]
): Promise<Committee> => {
    return await deployContract(
        "Committee",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(nodes),
            commonPubilicKey
        ]
    ) as Committee;
}

const deployNodes = async (accessManager: PlayaAccessManager, nodeList: INodes.NodeStruct[]): Promise<Nodes> => {
    return await deployContract(
        "Nodes",
        [
            await ethers.resolveAddress(accessManager),
            nodeList
        ]
    ) as Nodes;
}

const deployDkg = async (authority: PlayaAccessManager, committee: Committee, nodes: Nodes): Promise<DKG> => {
    return await deployContract(
        "DKG",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(committee),
            await ethers.resolveAddress(nodes)
        ]
    ) as DKG;
}

const deployStatus = async (authority: PlayaAccessManager, nodes: Nodes): Promise<Status> => {
    return await deployContract(
        "Status",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(nodes)
        ]
    ) as Status;
}

const deployStaking = async (authority: PlayaAccessManager): Promise<Staking> => {
    return await deployContract(
        "Staking",
        [
            await ethers.resolveAddress(authority)
        ]
    ) as Staking;
}

const storeAddresses = async (deployedContracts: DeployedContracts, version: string) => {
    const addresses = Object.fromEntries(await Promise.all(Object.entries(deployedContracts).map(
            async ([name, contract]) => [name, await ethers.resolveAddress(contract)]
    )));
    for (const contract in addresses) {
        console.log(`${contract}: ${addresses[contract]}`);
    }
    await fs.writeFile(
        `data/playa-manager-${version}-${network.name}-contracts.json`,
        JSON.stringify(addresses, null, 4));
}

const main = async () => {
    const version = await getVersion();

    console.log("Deploy contracts");

    const deployedContracts = await deploy();

    console.log("Store addresses")

    await storeAddresses(deployedContracts, version);

    console.log("Done");
};

if (require.main === module) {
    main().catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}
