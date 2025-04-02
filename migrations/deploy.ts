import { ethers, network, upgrades } from "hardhat";
import { promises as fs } from 'fs';
import {
    getVersion
} from '@skalenetwork/upgrade-tools';
import { Committee, DKG, Nodes, PlayaAccessManager, Staking, Status } from "../typechain-types";
import { AddressLike } from "ethers";


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

export const deploy = async (): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    let deployedContracts: DeployedContracts = {} as DeployedContracts;

    deployedContracts.PlayaAccessManager = await deployPlayaAccessManager(deployer);
    deployedContracts.Committee = await deployCommittee(deployedContracts.PlayaAccessManager);
    deployedContracts.Nodes = await deployNodes(
        deployedContracts.PlayaAccessManager,
        deployedContracts.Committee
    );
    deployedContracts.DKG = await deployDkg(
        deployedContracts.PlayaAccessManager,
        deployedContracts.Committee,
        deployedContracts.Nodes
    );
    const deployed = new Set(["PlayaAccessManager", "Committee", "Nodes", "DKG"]);
    const toDeploy = contracts.filter( c => !deployed.has(c));
    for (const contract of toDeploy) {
        const parameters = [];

        parameters.push(await ethers.resolveAddress(deployedContracts["PlayaAccessManager"]));
        if (contract === "Status") {
            parameters.push(await ethers.resolveAddress(deployedContracts["Nodes"]));
        }

        const instance = await deployContract(contract, parameters);
        deployedContracts = {
            ...deployedContracts,
            [contract]: instance
        }
    }

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

const deployCommittee = async (authority: PlayaAccessManager): Promise<Committee> => {
    return await deployContract(
        "Committee",
        [
            await ethers.resolveAddress(authority)
        ]
    ) as Committee;
}

const deployNodes = async (
    accessManager: PlayaAccessManager,
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
