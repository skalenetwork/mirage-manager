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
    FairAccessManager,
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
    "FairAccessManager",
    "Status",
    "Staking"
];

interface DeployedContracts {
    Committee: Committee,
    DKG: DKG,
    Nodes: Nodes,
    FairAccessManager: FairAccessManager,
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
    const fairChainName = getEnvVar("CHAIN_NAME");
    const fairChainHash = ethers.solidityPackedKeccak256(
        ["string"],
        [fairChainName]
    );
    const skaleManagerInstance = await getSkaleManagerInstance();
    const nodes = await skaleManagerInstance.getContract("Nodes") as unknown as INodesInSkaleManager;
    const schainsInternal = await skaleManagerInstance.getContract("SchainsInternal") as unknown as ISchainsInternal;
    const nodesInGroup = await schainsInternal.getNodesInGroup(fairChainHash);
    const nodeList: INodes.NodeStruct[] = [];
    for (const nodeId of nodesInGroup) {
        const [ip, domainName ,nodeAddress, port, publicKey] = await Promise.all([
            nodes.getNodeIP(nodeId),
            nodes.getNodeDomainName(nodeId),
            nodes.getNodeAddress(nodeId),
            nodes.getNodePort(nodeId),
            nodes.getNodePublicKey(nodeId)
        ]);
        nodeList.push({
            id: 0,
            ip,
            domainName,
            nodeAddress,
            port,
            publicKey
        });
    }
    return nodeList;
}

async function fetchDkgCommonPublicKey() {
    const fairChainName = getEnvVar("CHAIN_NAME");
    const fairChainHash = ethers.solidityPackedKeccak256(
        ["string"],
        [fairChainName]
    );
    const skaleManagerInstance = await getSkaleManagerInstance();
    const dkg = await skaleManagerInstance.getContract("KeyStorage") as unknown as IKeyStorage;
    const commonPublicKey = await dkg.getCommonPublicKey(fairChainHash);
    return commonPublicKey;
}

export const deploy = async (nodeList?: INodes.NodeStruct[], commonPublicKey?: IDkg.G2PointStruct): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    const deployedContracts: DeployedContracts = {} as DeployedContracts;
    nodeList = nodeList || await fetchNodes();
    commonPublicKey = commonPublicKey ||  await fetchDkgCommonPublicKey();

    deployedContracts.FairAccessManager = await deployFairAccessManager(deployer);
    deployedContracts.Nodes = await deployNodes(
        deployedContracts.FairAccessManager,
        nodeList
    );
    deployedContracts.Committee = await deployCommittee(
        deployedContracts.FairAccessManager,
        deployedContracts.Nodes,
        commonPublicKey
    );
    deployedContracts.DKG = await deployDkg(
        deployedContracts.FairAccessManager,
        deployedContracts.Committee,
        deployedContracts.Nodes
    );
    deployedContracts.Status = await deployStatus(
        deployedContracts.FairAccessManager,
        deployedContracts.Nodes,
        deployedContracts.Committee
    );
    deployedContracts.Staking = await deployStaking(
        deployedContracts.FairAccessManager,
        deployedContracts.Committee,
        deployedContracts.Nodes
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

    await setupRoles(deployedContracts);

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

const deployFairAccessManager = async (
    owner: AddressLike
): Promise<FairAccessManager> => {
    return await deployContract(
        "FairAccessManager",
        [await ethers.resolveAddress(owner)]
    ) as FairAccessManager;
}

const deployCommittee = async (
    authority: FairAccessManager,
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

const deployNodes = async (accessManager: FairAccessManager, nodeList: INodes.NodeStruct[]): Promise<Nodes> => {
    return await deployContract(
        "Nodes",
        [
            await ethers.resolveAddress(accessManager),
            nodeList
        ]
    ) as Nodes;
}

const deployDkg = async (authority: FairAccessManager, committee: Committee, nodes: Nodes): Promise<DKG> => {
    return await deployContract(
        "DKG",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(committee),
            await ethers.resolveAddress(nodes)
        ]
    ) as DKG;
}

const deployStatus = async (authority: FairAccessManager, nodes: Nodes, committee: Committee): Promise<Status> => {
    return await deployContract(
        "Status",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(nodes),
            await ethers.resolveAddress(committee)
        ]
    ) as Status;
}

const deployStaking = async (authority: FairAccessManager, committee: Committee, nodes: Nodes): Promise<Staking> => {
    return await deployContract(
        "Staking",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(committee),
            await ethers.resolveAddress(nodes)
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
        `data/fair-manager-${version}-${network.name}-contracts.json`,
        JSON.stringify(addresses, null, 4));
}

const setupRoles = async (deployedContracts: DeployedContracts) => {
    const {
        Committee: committee,
        FairAccessManager: accessManager,
        Nodes: nodes,
        Staking: staking,
        Status: status
    } = deployedContracts;

    // set up roles

    let response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [committee.interface.getFunction("nodeCreated").selector],
        await accessManager.NODES_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [committee.interface.getFunction("nodeBlacklisted").selector],
        await accessManager.STATUS_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [committee.interface.getFunction("nodeWhitelisted").selector],
        await accessManager.STATUS_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [committee.interface.getFunction("processHeartbeat").selector],
        await accessManager.STATUS_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [committee.interface.getFunction("updateWeight").selector],
        await accessManager.STAKING_ROLE()
    );
    await response.wait();

    // grant roles

    response = await accessManager.grantRole(await accessManager.NODES_ROLE(), await ethers.resolveAddress(nodes), 0n);
    await response.wait();

    response = await accessManager.grantRole(await accessManager.STATUS_ROLE(), await ethers.resolveAddress(status), 0n);
    await response.wait();

    response = await accessManager.grantRole(await accessManager.STAKING_ROLE(), await ethers.resolveAddress(staking), 0n);
    await response.wait();
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
