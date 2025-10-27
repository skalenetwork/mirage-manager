import chalk from "chalk";
import { ethers, network, upgrades } from "hardhat";
import { promises as fs } from 'fs';
import {
    getVersion,
    verify as verifyImplementation,
    verifyProxy
} from '@skalenetwork/upgrade-tools';
import {
    Committee,
    DKG,
    IDkg,
    INodes,
    Nodes,
    FairAccessManager,
    Staking,
    Status,
    IBeacon
} from "../typechain-types";
import { AddressLike, BigNumberish, BytesLike } from "ethers";
import { skaleContracts } from "@skalenetwork/skale-contracts-ethers-v6";
import {
    IKeyStorage,
    INodes as INodesInSkaleManager,
    ISchainsInternal,
} from "../typechain-types/@skalenetwork/skale-manager-interfaces";
import { configurePermissions } from "./permissions";
import { TypedContractMethod } from "../typechain-types/common";


export const contracts = [
    "Committee",
    "DKG",
    "Nodes",
    "FairAccessManager",
    "RewardWallet",
    "Status",
    "Staking"
];

export interface NodeStruct extends INodes.NodeStruct {
    publicKey: [BytesLike, BytesLike];
}

export interface DeployedContracts {
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
    console.log("Fetch nodes from SKALE Manager");
    const fairChainName = getEnvVar("CHAIN_NAME");
    const fairChainHash = ethers.solidityPackedKeccak256(
        ["string"],
        [fairChainName]
    );
    const skaleManagerInstance = await getSkaleManagerInstance();
    const nodes = await skaleManagerInstance.getContract("Nodes") as unknown as INodesInSkaleManager;
    const schainsInternal = await skaleManagerInstance.getContract("SchainsInternal") as unknown as ISchainsInternal;
    const nodeIds = await schainsInternal.getNodesInGroup(fairChainHash);
    if (nodeIds.includes(0n)) {
        throw new Error("Node IDs cannot contain 0");
    }
    const nodeList: NodeStruct[] = [];

    const callWithRetry = async <T> (
        method: TypedContractMethod<[BigNumberish], [T], "view">,
        node: BigNumberish,
        retries = 10,
        maxDelayMs = 10000): Promise<T> => {
        for (let attempt = 1; attempt <= retries; attempt++) {
            try {
                return await method.staticCall(node);
            } catch (error) {
                if (attempt === retries) {
                    throw error;
                }
                const delay = Math.round(maxDelayMs * Math.random());
                console.log(chalk.yellow(`Error during calling ${method.name}(${node})`));
                console.log(chalk.gray(`Retrying in ${delay / 1000}s... (${attempt}/${retries})`));
                await new Promise(res => setTimeout(res, delay));
            }
        }
        throw new Error("Unknown error");
    }

    for (const nodeId of nodeIds) {
        const [ip, domainName ,nodeAddress, port, publicKey] = await Promise.all([
            callWithRetry(nodes.getNodeIP, nodeId),
            callWithRetry(nodes.getNodeDomainName, nodeId),
            callWithRetry(nodes.getNodeAddress, nodeId),
            callWithRetry(nodes.getNodePort, nodeId),
            callWithRetry(nodes.getNodePublicKey, nodeId)
        ]);
        nodeList.push({
            id: nodeId,
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
    console.log("Fetch DKG common public key from SKALE Manager");
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

export const deploy = async (nodeList?: NodeStruct[], commonPublicKey?: IDkg.G2PointStruct): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    const deployedContracts: DeployedContracts = {} as DeployedContracts;
    nodeList = nodeList || await fetchNodes();
    commonPublicKey = commonPublicKey || await fetchDkgCommonPublicKey();

    deployedContracts.FairAccessManager = await deployFairAccessManager(deployer);
    deployedContracts.Nodes = await deployNodes(
        deployedContracts.FairAccessManager,
        [...nodeList].sort((a, b) => Number(a.id) - Number(b.id))
    );
    deployedContracts.Committee = await deployCommittee(
        deployedContracts.FairAccessManager,
        deployedContracts.Nodes,
        commonPublicKey,
        nodeList.map(node => BigInt(node.id))
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
        deployedContracts.Nodes,
        nodeList
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

    await configurePermissions(deployedContracts);

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
    commonPublicKey: IDkg.G2PointStruct,
    nodeIds: bigint[]
): Promise<Committee> => {
    return await deployContract(
        "Committee",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(nodes),
            commonPublicKey,
            nodeIds
        ]
    ) as Committee;
}

const deployNodes = async (accessManager: FairAccessManager, nodeList: NodeStruct[]): Promise<Nodes> => {
    return await deployContract(
        "Nodes",
        [
            await ethers.resolveAddress(accessManager),
            nodeList,
            nodeList.map(node => node.publicKey)
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

export const deployRewardWalletBeacon = async (owner: AddressLike): Promise<IBeacon> => {
    const instance = await upgrades.deployBeacon(
        await ethers.getContractFactory("RewardWallet"),
        {
            initialOwner: await ethers.resolveAddress(owner)
        }
    );
    await instance.waitForDeployment();
    return instance as unknown as IBeacon;
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

const deployStaking = async (
    authority: FairAccessManager,
    committee: Committee,
    nodes: Nodes,
    initialNodes: NodeStruct[]
): Promise<Staking> => {
    const [owner] = await ethers.getSigners();
    const rewardWalletBeacon = await deployRewardWalletBeacon(owner);
    const staking = await deployContract(
        "Staking",
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(committee),
            await ethers.resolveAddress(nodes),
            await ethers.resolveAddress(rewardWalletBeacon)
        ]
    ) as Staking;

    // Call this because it's a reinitializer
    await staking.updateRewardWalletBeacon(rewardWalletBeacon);

    // Nodes contract is deployed before Staking
    // so the Staking contract can't be notified about initially existing nodes
    // Providing this list to the initializer does not work
    // because proxy admin address is not accessible in the initializer
    // and corresponding RewardWallets can't be deployed
    // To workaround this issue manually notify Staking about initial nodes

    const selfStakeRequirement = await staking.selfStakeRequirement();
    await staking.setSelfStakeRequirement(0n);
    for (const node of initialNodes) {
        const response = await staking.nodeCreated(node.id, node.nodeAddress);
        await response.wait();
    }
    await staking.setSelfStakeRequirement(selfStakeRequirement);

    return staking;
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

const verify = async (deployedContracts: DeployedContracts) => {
    console.log("Verify contracts");
    for (const contractName in deployedContracts) {
        try {
            await verifyProxy(contractName, await ethers.resolveAddress(deployedContracts[contractName as keyof DeployedContracts]));
        } catch (error) {
            console.log(chalk.yellow(`Skipping verification for ${contractName}: ${error}`));
        }
    }
    try {
        const rewardWalletBeacon = await ethers.getContractAt(
            "IBeacon",
            await deployedContracts.Staking.rewardWalletBeacon()
        );
        await verifyImplementation(
            "RewardWallet",
            await rewardWalletBeacon.implementation()
        );
    } catch (error) {
        console.log(chalk.yellow(`Skipping verification for RewardWallet: ${error}`));
    }
}

const main = async () => {
    const version = await getVersion();

    console.log("Deploy contracts");

    const deployedContracts = await deploy();

    console.log("Store addresses")

    await storeAddresses(deployedContracts, version);

    await verify(deployedContracts);

    console.log("Done");
};

if (require.main === module) {
    main().catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}
