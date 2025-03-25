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

const deployDkg = async (authority: AddressLike, committee: Committee, nodes: Nodes): Promise<DKG> => {
    const factory = await ethers.getContractFactory("DKG");
    const instance = await upgrades.deployProxy(
        factory,
        [
            await ethers.resolveAddress(authority),
            await ethers.resolveAddress(committee),
            await ethers.resolveAddress(nodes)
        ]
    );
    await instance.waitForDeployment();
    return instance as DKG;
}

export const deploy = async (): Promise<DeployedContracts> => {
    const [deployer] = await ethers.getSigners();
    let deployedContracts: DeployedContracts = {} as DeployedContracts;

    deployedContracts.PlayaAccessManager = await deployContract(
        "PlayaAccessManager",
        [await ethers.resolveAddress(deployer)]
    ) as PlayaAccessManager;

    deployedContracts.Committee = await deployContract(
        "Committee",
        [await ethers.resolveAddress(deployedContracts.PlayaAccessManager)]
    ) as Committee;

    deployedContracts.Nodes = await deployNodes(
        await ethers.resolveAddress(deployedContracts.PlayaAccessManager),
        await ethers.resolveAddress(deployedContracts.Committee)
    );
    const deployed = new Set(["PlayaAccessManager", "Committee", "Nodes"]);
    const toDeploy = contracts.filter( c => !deployed.has(c));
    for (const contract of toDeploy) {
        const parameters = [];

        parameters.push(await ethers.resolveAddress(deployedContracts["PlayaAccessManager"]));
        if (contract === "DKG") {
            parameters.push(await ethers.resolveAddress(deployedContracts["Committee"]));
            parameters.push(await ethers.resolveAddress(deployedContracts["Nodes"]));
        }
        const instance = await deployContract(contract, parameters);
        deployedContracts = {
            ...deployedContracts,
            [contract]: instance
        }
    }

    deployedContracts.DKG = await deployDkg(deployer, deployedContracts.Committee, deployedContracts.Nodes);
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
const deployNodes = async (
    accessManagerAddress: string,
    committeeAddress: string,
): Promise<Nodes> => {
    return await deployContract(
        "Nodes",
        [accessManagerAddress, committeeAddress]
    ) as Nodes;
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
