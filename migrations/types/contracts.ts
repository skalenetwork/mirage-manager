import { BaseContract } from "ethers";

export interface SchainsInternalContract extends BaseContract {
    getNodesInGroup(schainHash: string): Promise<number[]>;
}

export interface NodesContract extends BaseContract {
    getNodeIP(nodeId: number): Promise<string>;
    getNodeDomainName(nodeId: number): Promise<string>;
    getNodeAddress(nodeId: number): Promise<string>;
    getNodePort(nodeId: number): Promise<number>;
}

export interface KeyStorageContract extends BaseContract {
    getCommonPublicKey(chainHash: string): Promise<[string, string, string, string]>;
}
