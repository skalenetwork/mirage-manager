import { ethers } from "hardhat";
import { DeployedContracts } from "./deploy";
import { Committee, FairAccessManager, Staking, Status } from "../typechain-types";

const setupCommitteeRoles = async (accessManager: FairAccessManager, committee: Committee) => {
    let response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [
            committee.interface.getFunction("nodeCreated").selector,
            committee.interface.getFunction("nodeRemoved").selector
        ],
        await accessManager.NODES_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [
            committee.interface.getFunction("nodeBlacklisted").selector,
            committee.interface.getFunction("nodeWhitelisted").selector,
            committee.interface.getFunction("processHeartbeat").selector
        ],
        await accessManager.STATUS_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(committee),
        [committee.interface.getFunction("updateWeight").selector],
        await accessManager.STAKING_ROLE()
    );
    await response.wait();
}

const setupStakeRoles = async (accessManager: FairAccessManager, staking: Staking) => {
    let response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(staking),
        [
            staking.interface.getFunction("disable").selector,
            staking.interface.getFunction("enable").selector
        ],
        await accessManager.COMMITTEE_ROLE()
    );
    await response.wait();

    response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(staking),
        [staking.interface.getFunction("nodeCreated").selector],
        await accessManager.NODES_ROLE()
    );
    await response.wait();
}

const setupStatusRoles = async (accessManager: FairAccessManager, status: Status) => {
    const response = await accessManager.setTargetFunctionRole(
        await ethers.resolveAddress(status),
        [status.interface.getFunction("nodeRemoved").selector],
        await accessManager.NODES_ROLE()
    );
    await response.wait();
}

const setupRoles = async (deployedContracts: DeployedContracts) => {
    const {
        Committee: committee,
        FairAccessManager: accessManager,
        Staking: staking,
        Status: status
    } = deployedContracts;

    await setupCommitteeRoles(accessManager, committee);
    await setupStakeRoles(accessManager, staking);
    await setupStatusRoles(accessManager, status);
}

const grantRoles = async (deployedContracts: DeployedContracts) => {
    const {
        Committee: committee,
        FairAccessManager: accessManager,
        Nodes: nodes,
        Staking: staking,
        Status: status
    } = deployedContracts;

    let response = await accessManager.grantRole(await accessManager.COMMITTEE_ROLE(), await ethers.resolveAddress(committee), 0n);
    await response.wait();

    response = await accessManager.grantRole(await accessManager.NODES_ROLE(), await ethers.resolveAddress(nodes), 0n);
    await response.wait();

    response = await accessManager.grantRole(await accessManager.STAKING_ROLE(), await ethers.resolveAddress(staking), 0n);
    await response.wait();

    response = await accessManager.grantRole(await accessManager.STATUS_ROLE(), await ethers.resolveAddress(status), 0n);
    await response.wait();
}

export const configurePermissions = async (deployedContracts: DeployedContracts) => {
    console.log("Setting up roles")
    await setupRoles(deployedContracts);

    console.log("Granting roles")
    await grantRoles(deployedContracts);
}
