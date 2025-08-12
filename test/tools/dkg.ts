import { assert } from "chai";
import { IDkg } from "../../typechain-types";
import { NodeData } from "./fixtures";

export const DkgStatus = {
    SUCCESS: 0n,
    BROADCAST: 1n,
    ALRIGHT: 2n,
    FAILED: 3n
};

export const toEventFormat = (data: unknown): unknown => {
    if (Array.isArray(data)) {
        return data.map(toEventFormat);
    } else if (typeof data === "object") {
        if (data === null) {
            return null;
        }
        return toEventFormat(Object.entries(data).sort().map(([, value]) => value));
    } else {
        return data;
    }
}

const getT = (n: number) => {
    return Math.floor((n * 2 + 1) / 3);
};

const getVerificationVector = (n: number) => {
    const exampleVerificationVectorElement = {
        x: {
            a: "0x2603b519d8eacb84244da4f264a888b292214ed2d2fad9368bc12c2a9a5a5f25",
            b: "0x2d8b197411929589919db23a989c1fd619a53a47db14dab3fd952490c7bf0615"
        },
        y: {
            a: "0x2e99d40faf53cc640065fa674948a0a9b169c303afc5d061bac6ef4c7c1fc400",
            b: "0x1b9afd2c7c3aeb9ef31f357491d4f1c2b889796297460facaa81ce8c15c3680"
        }
    };
    return Array<IDkg.G2PointStruct>(getT(n)).fill(exampleVerificationVectorElement);
}

const getSecretKeyContribution = (n: number) => {
    const exampleKeyShare: IDkg.KeyShareStruct = {
        share: "0xc54860dc759e1c6095dfaa33e0b045fc102551e654cec47c7e1e9e2b33354ca6",
        publicKey: [
            "0xf676847eeff8f52b6f22c8b590aed7f80c493dfa2b7ec1cff3ae3049ed15c767",
            "0xe5c51a3f401c127bde74fefce07ed225b45e7975fccf4a10c12557ae8036653b"
        ]
    }
    return Array<IDkg.KeyShareStruct>(n).fill(exampleKeyShare);
}

export const runDkg = async (dkg: IDkg, nodesData: NodeData[], dkgId: bigint) => {
    // send broadcast
    const participants = await dkg.getParticipants(dkgId);
    for (const nodeId of participants) {
        const node = nodesData.find((node) => node.id === nodeId);
        assert(node);
        await dkg.connect(node.wallet).broadcast(
            dkgId,
            getVerificationVector(participants.length),
            getSecretKeyContribution(participants.length)
        );
    }

    // send alright
    for (const nodeId of participants) {
        const node = nodesData.find((node) => node.id === nodeId);
        assert(node);
        await dkg.connect(node.wallet).alright(dkgId);
    }
}
