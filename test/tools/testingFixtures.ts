import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { FieldOperationsTester, RedBlackTreeTester } from "../../typechain-types";

const deployFieldOperationsTester = async () => {
    const factory = await ethers.getContractFactory("FieldOperationsTester");
    return {fieldOperationsTester: await factory.deploy() as FieldOperationsTester};
}

const deployRedBlackTreeTester = async () => {
    const factory = await ethers.getContractFactory("RedBlackTreeTester");
    return {redBlackTreeTester: await factory.deploy() as RedBlackTreeTester};
}

export const fieldOperationsTester = async () => loadFixture(deployFieldOperationsTester);
export const redBlackTreeTester = async () => loadFixture(deployRedBlackTreeTester);
