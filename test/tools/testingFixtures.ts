import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { FieldOperationsTester, SplayTreeTester } from "../../typechain-types";

const deployFieldOperationsTester = async () => {
    const factory = await ethers.getContractFactory("FieldOperationsTester");
    return {fieldOperationsTester: await factory.deploy() as FieldOperationsTester};
}

const deploySplayTreeTester = async () => {
    const factory = await ethers.getContractFactory("SplayTreeTester");
    return {splayTreeTester: await factory.deploy() as SplayTreeTester};
}

export const fieldOperationsTester = async () => loadFixture(deployFieldOperationsTester);
export const splayTreeTester = async () => loadFixture(deploySplayTreeTester);
