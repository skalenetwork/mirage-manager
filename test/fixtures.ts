import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import { deploy as productionDeploy } from "../migrations/deploy";

const deploy = async () => {
    const contracts = await productionDeploy();
    return {
        committee: contracts.Committee,
        dkg: contracts.DKG,
        nodes: contracts.Nodes,
        staking: contracts.Staking,
        status: contracts.Status
    }
}

export const cleanDeployment = async () => loadFixture(deploy);
