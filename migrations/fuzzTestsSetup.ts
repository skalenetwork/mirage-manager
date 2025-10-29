import { ethers, upgrades } from "hardhat";
import { commonPublicKey, generateRandomNodes } from "../test/tools/fixtures";
import { deploy } from "./deploy";

/*
* Deployment used for fuzz tests
*
*/
const main = async () => {

    console.log("Deploy contracts");
    const deployedContracts = await deploy(await generateRandomNodes(22), commonPublicKey);
    console.log("Done");

    const addresses = Object.fromEntries(await Promise.all(Object.entries(deployedContracts).map(
            async ([name, contract]) => [name, await ethers.resolveAddress(contract)]
    )));
    console.log("DEPLOYER:", await ethers.resolveAddress((await ethers.getSigners())[0].address));
    for (const contract in addresses) {
        console.log(`${contract}: ${addresses[contract]}`);
    }

    // Upgrade for testers
    const committeeTesterFactory = await ethers.getContractFactory("CommitteeTester");
    await upgrades.upgradeProxy(deployedContracts.Committee, committeeTesterFactory);
};

if (require.main === module) {
    main().catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}