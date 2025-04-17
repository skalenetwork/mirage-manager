import chalk from "chalk";
import { ethers, network, upgrades } from "hardhat";
import { promises as fs } from 'fs';
import {
    getVersion
} from '@skalenetwork/upgrade-tools';
import {
    Committee,
    DKG,
    IDkg,
    INodes,
    Nodes,
    MirageAccessManager,
    Staking,
    Status
} from "../typechain-types";
import { AddressLike } from "ethers";
import { skaleContracts } from "@skalenetwork/skale-contracts-ethers-v6";
import {
    IKeyStorage,
    INodes as INodesInSkaleManager,
    ISchainsInternal,
} from "../typechain-types/@skalenetwork/skale-manager-interfaces";


export const contracts = [
    "Committee",
    "DKG",
    "Nodes",
    "MirageAccessManager",
    "Status",
    "Staking"
];

interface DeployedContracts {
    Committee: Committee,
    DKG: DKG,
    Nodes: Nodes,
    MirageAccessManager: MirageAccessManager,
    Staking: Staking,
    Status: Status
}

function getEnvVar(name: string): string {
    const value = process.env[name];
    if (!value) {
        console.log(chalk.red(`Set ${name} environment variable.`));
        process.exit(1);
    }
    return value;
}

async function getSkaleManagerInstance() {
    const target = getEnvVar("TARGET");
    const mainnetEndpoint = getEnvVar("MAINNET_ENDPOINT");
    const mainnetProvider = new ethers.JsonRpcProvider(mainnetEndpoint);
    const network = await skaleContracts.getNetworkByProvider(mainnetProvider);
    const project = network.getProject("skale-manager");
    return await project.getInstance(target);
}

async function fetchNodes() {
    const mirageChainHash = getEnvVar("CHAIN_HASH");
    const skaleManagerInstance = await getSkaleManagerInstance();
    const nodes = await skaleManagerInstance.getContract("Nodes") as unknown as INodesInSkaleManager;
    const schainsInternal = await skaleManagerInstance.getContract("SchainsInternal") as unknown as ISchainsInternal;
    const nodesInGroup = await schainsInternal.getNodesInGroup(mirageChainHash);
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
    const mirageChainHash = getEnvVar("CHAIN_HASH");
    const skaleManagerInstance = await getSkaleManagerInstance();
    const dkg = await skaleManagerInstance.getContract("KeyStorage") as unknown as IKeyStorage;
    const commonPublicKey = await dkg.getCommonPublicKey(mirageChainHash);
    return commonPublicKey;
}

export const deploy = async (nodeList?: INodes.NodeStruct[], commonPublicKey?: IDkg.G2PointStruct): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    const deployedContracts: DeployedContracts = {} as DeployedContracts;
    nodeList = nodeList || await fetchNodes();
    commonPublicKey = commonPublicKey ||  await fetchDkgCommonPublicKey();

    deployedContracts.MirageAccessManager = await deployMirageAccessManager(deployer);
    deployedContracts.Nodes = await deployNodes(
        deployedContracts.MirageAccessManager,
        nodeList
    );
    deployedContracts.Committee = await deployCommittee(
        deployedContracts.MirageAccessManager,
        deployedContracts.Nodes,
        commonPublicKey
    );
    deployedContracts.DKG = await deployDkg(
        deployedContracts.MirageAccessManager,
        deployedContracts.Committee,
        deployedContracts.Nodes
    );
    deployedContracts.Status = await deployStatus(
        deployedContracts.MirageAccessManager,
        deployedContracts.Nodes
    );
    deployedContracts.Staking = await deployStaking(
        deployedContracts.MirageAccessManager
    );

    let response = await deployedContracts.Committee.setDkg(deployedContracts.DKG);
    await response.wait();
    response = await deployedContracts.Committee.setNodes(deployedContracts.Nodes);
    await response.wait();
    response = await deployedContracts.Committee.setStatus(deployedContracts.Status);
    await response.wait();
    response = await deployedContracts.Nodes.setCommittee(deployedContracts.Committee);
    await response.wait();
    response = await deployedContracts.Committee.setStaking(deployedContracts.Staking);
    await response.wait();

    await (await deployedContracts.Committee.setVersion(await getVersion())).wait();

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

const deployMirageAccessManager = async (
    owner: AddressLike
): Promise<MirageAccessManager> => {
    return await deployContract(
        "MirageAccessManager",
        [await ethers.resolveAddress(owner)]
    ) as MirageAccessManager;
}

const deployCommittee = async (
    authority: MirageAccessManager,
    nodes: Nodes,
    commonPublicKey: IDkg.G2PointStruct
): Promise<Committee> => {
    return await deployContract(
        "Committee",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(nodes),
            commonPublicKey
        ]
    ) as Committee;
}

const deployNodes = async (accessManager: MirageAccessManager, nodeList: INodes.NodeStruct[]): Promise<Nodes> => {
    return await deployContract(
        "Nodes",
        [
            await ethers.resolveAddress(accessManager),
            nodeList
        ]
    ) as Nodes;
}

const deployDkg = async (authority: MirageAccessManager, committee: Committee, nodes: Nodes): Promise<DKG> => {
    return await deployContract(
        "DKG",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(committee),
            await ethers.resolveAddress(nodes)
        ]
    ) as DKG;
}

const deployStatus = async (authority: MirageAccessManager, nodes: Nodes): Promise<Status> => {
    return await deployContract(
        "Status",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(nodes)
        ]
    ) as Status;
}

const deployStaking = async (authority: MirageAccessManager): Promise<Staking> => {
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
        `data/mirage-manager-${version}-${network.name}-contracts.json`,
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
