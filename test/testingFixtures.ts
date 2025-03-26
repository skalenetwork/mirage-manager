import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { FieldOperationsTester } from "../typechain-types";

const deployFieldOperationsTester = async () => {
    const factory = await ethers.getContractFactory("FieldOperationsTester");
    return {fieldOperationsTester: await factory.deploy() as FieldOperationsTester};
}

export const fieldOperationsTester = async () => loadFixture(deployFieldOperationsTester);
