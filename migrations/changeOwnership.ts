import {skaleContracts} from "@skalenetwork/skale-contracts-ethers-v6";
import {contracts} from "./deploy";
import {ethers} from "hardhat";
import {EoaSubmitter, InstanceAdmin, InstanceAdminOptions, SafeSubmitter} from "@skalenetwork/upgrade-tools";

async function main() {
    const contractsWithOwnershipToChange = contracts.filter(c => c !== "RewardWallet");
    let readonly = false;
    let renounceRoles = true;
    let testMode = false;
    let oldOwner: string;
    let submitter: EoaSubmitter | SafeSubmitter;

    if (!process.env.NEW_OWNER) {
        throw new Error("Please set NEW_OWNER env variable");
    }

    if (!process.env.TARGET) {
        throw new Error("Please set TARGET env variable");
    }

    if (process.env.READONLY) {
        readonly = process.env.READONLY === "true";
    }

    if (process.env.TEST_MODE === "true") {
        readonly = false;
        renounceRoles = true;
        testMode = true;
    }

    if (process.env.RENOUNCE_ROLES) {
        renounceRoles = process.env.RENOUNCE_ROLES === "true";
    }

    // Set readonly variable if desired

    if (process.env.MULTISIG_OWNER) {
        oldOwner = process.env.MULTISIG_OWNER;
        submitter = new SafeSubmitter(oldOwner);
    } else {
        oldOwner = (await ethers.getSigners())[0].address;
        submitter = new EoaSubmitter();
    }

    const newOwner: string = process.env.NEW_OWNER;
    const network = await skaleContracts.getNetworkByProvider(ethers.provider);
    const project = network.getProject("fair-manager");
    const instance = await project.getInstance(process.env.TARGET);
    const configs: InstanceAdminOptions = {
        newOwner,
        readonly,
        renounceRoles,
        testMode,
        oldOwner,
        submitter,
    }
    const contractIds = contractsWithOwnershipToChange.map(c => ({name: c} as {name: string; address?: string}));
    const staking = await ethers.getContractAt("Staking", await instance.getContractAddress("Staking"));
    contractIds.push({name: "RewardWalletReference", address: await staking.rewardWalletBeacon()});
    const admin = new InstanceAdmin(
        contractIds,
        configs,
        instance
    );
    await admin.executeOwnershipTransfer();
}

if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch(error => {
            console.error(error);
            process.exit(1);
        });
}
