import {Instance, skaleContracts} from "@skalenetwork/skale-contracts-ethers-v6";
import {AbstractTransparentProxyUpgrader, BeaconUpgrader, Submitter, Upgrader} from "@skalenetwork/upgrade-tools";
import {Transaction} from "ethers";
import chalk from "chalk";
import {contracts, deployRewardWalletBeacon} from "./deploy";
import {ethers} from "hardhat";
import { Committee, Staking, Staking__factory } from "../typechain-types";

enum ExitCodes {
    OK,
    TARGET_IS_NOT_SET
}

const getFairManagerInstance = async () => {
    if (process.env.ABI) {
        console.log("This version of the upgrade script ignores manually provided ABI");
        console.log("Do not set ABI environment variable");
    }
    if (!process.env.TARGET) {
        console.log(chalk.red("Specify desired fair-manager instance"));
        console.log(chalk.red("Set instance alias or Committee contract address to TARGET environment variable"));
        process.exit(ExitCodes.TARGET_IS_NOT_SET);
    }
    const network = await skaleContracts.getNetworkByProvider(ethers.provider);
    const project = network.getProject("fair-manager");
    return await project.getInstance(process.env.TARGET);
}

interface UpgradeContext {
    targetVersion: string,
    instance: Instance,
    contractNamesToUpgrade: string[],
}

class FairManagerUpgrader extends Upgrader {
    constructor(
        context: UpgradeContext,
        submitter?: Submitter
    ) {
        super(
            {
                contractNamesToUpgrade: context.contractNamesToUpgrade,
                instance: context.instance,
                name: "fair-manager",
                version: context.targetVersion
            },
            submitter);
    }

    async getCommittee() {
        return await this.instance.getContract("Committee") as Committee;
    }

    getDeployedVersion = async () => {
        const committee = await this.getCommittee();
        try {
            return await committee.version();
        } catch {
            console.log(chalk.red("Can't read deployed version"));
        }
        return "";
    }

    setVersion = async (newVersion: string) => {
        const committee = await this.getCommittee();
        console.log(chalk.yellowBright(`Prepare transaction to set version to ${newVersion}`));
        this.transactions.push(Transaction.from({
            data: committee.interface.encodeFunctionData("setVersion", [newVersion]),
            to: await ethers.resolveAddress(committee)
        }));
    }

    protected async createProxyUpgrader(contractName: string) {
        if (contractName === "RewardWallet") {
            const staking = await this.instance.getContract("Staking") as Staking;
            const rewardWalletBeaconAddress = await staking.rewardWalletBeacon();
            return new BeaconUpgrader(
                contractName,
                rewardWalletBeaconAddress,
                this.nonceProvider
            );
        }
        return super.createProxyUpgrader(contractName);
    }

    initialize = async () => {
        const staking = await this.instance.getContract("Staking");
        const stakingProxyAdmin = await AbstractTransparentProxyUpgrader.getProxyAdmin(staking);
        const rewardWalletBeacon = await deployRewardWalletBeacon(await stakingProxyAdmin.owner());
        const newStakingInterface = Staking__factory.createInterface();
        console.log(chalk.yellowBright(`Prepare transaction to start using RewardWallet beacon at ${
            await ethers.resolveAddress(rewardWalletBeacon)
        }`));
        this.transactions.push(Transaction.from({
            data: newStakingInterface.encodeFunctionData("updateRewardWalletBeacon", [
                await ethers.resolveAddress(rewardWalletBeacon)
            ]),
            to: await ethers.resolveAddress(staking)
        }));
    }
}

const main = async () => {
    const fairManager = await getFairManagerInstance();

    // TODO: remove this code
    // after RewardWallet beacon is released
    let updateRewardWallet = true;
    try {
        const staking = await fairManager.getContract("Staking") as Staking;
        await staking.rewardWalletBeacon();
    } catch {
        updateRewardWallet = false;
    }
    let contractNamesToUpgrade = contracts;
    if (!updateRewardWallet) {
        contractNamesToUpgrade = contracts.filter(name => name !== "RewardWallet");
    }
    // end of TODO

    const upgrader = new FairManagerUpgrader({
        contractNamesToUpgrade,
        instance: fairManager,
        targetVersion: "0.0.1-beta.3"
    });
    await upgrader.upgrade();
}

if (require.main === module) {
    main().catch(error => {
            console.error(error);
            process.exitCode = 1;
        });
}
