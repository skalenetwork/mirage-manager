import { ethers, network, upgrades } from "hardhat";
import { promises as fs } from 'fs';
import {
    getVersion
} from '@skalenetwork/upgrade-tools';
import { Committee, DKG, Nodes, PlayaAccessManager, Staking, Status } from "../typechain-types";


export const contracts = [
    "PlayaAccessManager", // must be first
    "Committee",
    "Nodes",
    "DKG",
    "Staking",
    "Status"
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
    for (const contract of contracts) {
        const factory = await ethers.getContractFactory(contract);
        const parameters = [];
        if (contract === "PlayaAccessManager") {
            parameters.push(await ethers.resolveAddress(deployer));
        } else {
            parameters.push(await ethers.resolveAddress(deployedContracts["PlayaAccessManager"]));
            if (contract === "DKG") {
                parameters.push(await ethers.resolveAddress(deployedContracts["Committee"]));
                parameters.push(await ethers.resolveAddress(deployedContracts["Nodes"]));
            }
            else if (contract === "Nodes") {
                parameters.push(await ethers.resolveAddress(deployedContracts["Committee"]));
            }
        }
        const instance = await upgrades.deployProxy(factory, parameters);
        await instance.waitForDeployment();
        deployedContracts = {
            ...deployedContracts,
            [contract]: instance
        }
    }
    return deployedContracts as DeployedContracts;
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
