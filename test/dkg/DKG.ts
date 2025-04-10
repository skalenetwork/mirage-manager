import chai, { assert, expect } from "chai";
import { NodeData, nodesRegistered } from "../fixtures";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { DKG, IDkg } from "../../typechain-types";

chai.should();

const DkgStatus = {
    SUCCESS: 0n,
    BROADCAST: 1n,
    ALRIGHT: 2n,
    FAILED: 3n
};

const toEventFormat = (data: unknown): unknown => {
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

export const runDkg = async (dkg: DKG, nodesData: NodeData[], dkgId: bigint) => {
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

describe("DKG", () => {

    describe("when 2 nodes committee is created", () => {

        const committee = [10, 11];

        const encryptedSecretKeyContributions: {publicKey: [string, string], share: string}[][] = [
            [
                {
                    share: "0xc54860dc759e1c6095dfaa33e0b045fc102551e654cec47c7e1e9e2b33354ca6",
                    publicKey: [
                        "0xf676847eeff8f52b6f22c8b590aed7f80c493dfa2b7ec1cff3ae3049ed15c767",
                        "0xe5c51a3f401c127bde74fefce07ed225b45e7975fccf4a10c12557ae8036653b"
                    ]
                },
                {
                    share: "0xdb68ca3cb297158e493e137ce0ab5fddd2cec34b3a15a4ee1aec9dfcc61dfd15",
                    publicKey: [
                        "0xdc1282664acf84218bf29112357c78f46766c783e7b7ead43db07d5d9fd74ca9",
                        "0x85569644dc1a5bc374d3833a5c5ff3aaa26fa4050ff738d442b34087d4d8f3aa"
                    ]
                }
            ],
            [
                {
                    share: "0x7bb14ad459adba781466c3441e10eeb3148c152b4919b126a0166fd1dac824ba",
                    publicKey: [
                        "0x89051df58e7d7cec9c6816d65a17f068409aa37200cd544d263104c1b9dbd037",
                        "0x435e1a25c9b9f95627ec141e14826f0d0e798c793d470388865dccb461c19773"
                    ]
                },
                {
                    share: "0xa6b44d487799470fc5da3e359d21b976a146d7345ed90782c1d034d1ceef53bf",
                    publicKey: [
                        "0x78b59fd523f23097483958ec5cd4308e5805a261961fe629bf7dc9674ed2ec94",
                        "0xaa4244b53891263f79f6df64a82592dab46a6be903c29c15170d785e493ff9c2"
                    ]
                }
            ]
        ];

        const verificationVectors = [
            [
                {
                    x: {
                        a: "0x2603b519d8eacb84244da4f264a888b292214ed2d2fad9368bc12c2a9a5a5f25",
                        b: "0x2d8b197411929589919db23a989c1fd619a53a47db14dab3fd952490c7bf0615"
                    },
                    y: {
                        a: "0x2e99d40faf53cc640065fa674948a0a9b169c303afc5d061bac6ef4c7c1fc400",
                        b: "0x1b9afd2c7c3aeb9ef31f357491d4f1c2b889796297460facaa81ce8c15c3680"
                    }
                }
            ],
            [
                {
                    x: {
                        a: "0x2a21918482ff2503b08a38dd5bf119b1a0a6bca910dfd9052fa6792f01624f20",
                        b: "0xa55dec4eb79493ec63aed84aebbc016c2ab11e335d3d465519ffbfa15416ced",
                    },
                    y: {
                        a: "0x13b919159469023fad82fedae095a2359f600f0a8a09f32bab6250e1688f0852",
                        b: "0x269279ef4c2fcd6ca475c522406444ee79ffa796a645f9953b3d4d003f8f7294"
                    }
                }
            ]
        ];

        it("should start DKG", async () => {
            const { dkg } = await nodesRegistered();
            await dkg.generate(committee);

            (await dkg.rounds(1)).status.should.be.equal(DkgStatus.BROADCAST);
        });

        describe("generation is started", async () => {
            let firstNode: NodeData;
            let secondNode: NodeData;
            let randomNode: NodeData;
            let dkg: DKG;
            const dkgId = 1n;

            const generationIsStartedFixture = async () => {
                const { dkg, nodesData } = await nodesRegistered();
                const firstNode = nodesData[committee[0]];
                const secondNode = nodesData[committee[1]];
                const randomNode = nodesData[0];
                await dkg.generate([firstNode.id, secondNode.id]);

                return { dkg, firstNode, secondNode, randomNode };
            }

            beforeEach(async () => {
                const {
                    dkg: dkgContract,
                    firstNode: a,
                    secondNode: b,
                    randomNode: random
                } = await loadFixture(generationIsStartedFixture);
                firstNode = a;
                secondNode = b;
                randomNode = random;
                dkg = dkgContract;
            });

            it("should broadcast data from 1 node", async () => {
                (await dkg.isNodeBroadcasted(dkgId, firstNode.id)).should.be.equal(false);

                await expect(dkg.connect(firstNode.wallet).broadcast(
                    dkgId,
                    verificationVectors[0],
                    encryptedSecretKeyContributions[0]
                )).to.emit(dkg, "BroadcastAndKeyShare")
                    .withArgs(
                        dkgId,
                        firstNode.id,
                        toEventFormat(verificationVectors[0]),
                        toEventFormat(encryptedSecretKeyContributions[0])
                    );

                (await dkg.isNodeBroadcasted(dkgId, firstNode.id)).should.be.equal(true);
            });

            it("should broadcast data from 2 node", async () => {
                const { dkg, nodesData } = await nodesRegistered();
                const secondNode = nodesData[committee[1]];
                await dkg.generate(committee.map((index) => nodesData[index].id));
                const dkgId = 1n;

                (await dkg.isNodeBroadcasted(dkgId, secondNode.id)).should.be.equal(false);

                await expect(dkg.connect(secondNode.wallet).broadcast(
                    dkgId,
                    verificationVectors[1],
                    encryptedSecretKeyContributions[1]
                )).to.emit(dkg, "BroadcastAndKeyShare")
                    .withArgs(
                        dkgId,
                        secondNode.id,
                        toEventFormat(verificationVectors[1]),
                        toEventFormat(encryptedSecretKeyContributions[1])
                    );

                (await dkg.isNodeBroadcasted(dkgId, secondNode.id)).should.be.equal(true);
            });

            it("should rejected broadcast data from wrong node", async () => {
                await expect(dkg.connect(randomNode.wallet).broadcast(
                    dkgId,
                    verificationVectors[0],
                    encryptedSecretKeyContributions[0]
                )).to.be.revertedWithCustomError(dkg, "NodeDoesNotParticipateInDkg")
                    .withArgs(randomNode.id);
            });

            describe("when correct broadcasts sent", () => {

                const broadcastsAreSentFixture = async () => {
                    const { dkg, firstNode, secondNode } = await generationIsStartedFixture();
                    await dkg.connect(firstNode.wallet).broadcast(
                        dkgId,
                        verificationVectors[0],
                        encryptedSecretKeyContributions[0]
                    );
                    await dkg.connect(secondNode.wallet).broadcast(
                        dkgId,
                        verificationVectors[1],
                        encryptedSecretKeyContributions[1]
                    );
                    return { dkg, firstNode, secondNode };
                }

                beforeEach(async () => {
                    await loadFixture(broadcastsAreSentFixture);
                });

                it("should send alright from 1 node", async () => {
                    await expect(dkg.connect(firstNode.wallet).alright(
                        dkgId
                    )).to.emit(dkg, "AllDataReceived")
                        .withArgs(dkgId, firstNode.id, 0);
                });

                it("should send alright from 2 node", async () => {
                    await expect(dkg.connect(secondNode.wallet).alright(
                        dkgId
                    )).to.emit(dkg, "AllDataReceived")
                        .withArgs(dkgId, secondNode.id, 1);
                });

                it("should not send alright from random node", async () => {
                    await expect(dkg.connect(randomNode.wallet).alright(
                        dkgId
                    )).to.revertedWithCustomError(dkg, "NodeDoesNotParticipateInDkg")
                        .withArgs(randomNode.id);
                });

                it("should emit successful DKG event", async () => {
                    await dkg.connect(firstNode.wallet).alright(dkgId);
                    await expect(dkg.connect(secondNode.wallet).alright(dkgId))
                        .to.emit(dkg, "SuccessfulDkg")
                        .withArgs(dkgId);
                });
            });
        });
    });
});
