import { ethers, network, upgrades } from "hardhat";
import { promises as fs } from 'fs';
import {
    getVersion
} from '@skalenetwork/upgrade-tools';
import { Committee, DKG, Nodes, MirageAccessManager, Staking, Status } from "../typechain-types";
import { AddressLike } from "ethers";


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

export const deploy = async (): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    const deployedContracts: DeployedContracts = {} as DeployedContracts;

    deployedContracts.MirageAccessManager = await deployMirageAccessManager(deployer);
    deployedContracts.Committee = await deployCommittee(deployedContracts.MirageAccessManager);
    deployedContracts.Nodes = await deployNodes(
        deployedContracts.MirageAccessManager,
        deployedContracts.Committee
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

const deployCommittee = async (authority: MirageAccessManager): Promise<Committee> => {
    return await deployContract(
        "Committee",
        [
            await ethers.resolveAddress(authority)
        ]
    ) as Committee;
}

const deployNodes = async (
    accessManager: MirageAccessManager,
    committee: Committee,
): Promise<Nodes> => {
    return await deployContract(
        "Nodes",
        [
            await ethers.resolveAddress(accessManager),
            await ethers.resolveAddress(committee)
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
