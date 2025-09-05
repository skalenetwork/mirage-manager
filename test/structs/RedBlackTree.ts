import {
    SnapshotRestorer,
    takeSnapshot
} from "@nomicfoundation/hardhat-network-helpers";
import chai from "chai";
import _ from 'lodash';
import { RedBlackTreeTester } from "../../typechain-types";
import { redBlackTreeTester } from "../tools/testingFixtures";

chai.should();

describe("Red-black tree", () => {
    describe("stress tests", () => {
        const maxN = 5; // it was completely run with 6, for very long time with 7
        let snapshot: SnapshotRestorer;
        let redBlackTree: RedBlackTreeTester;

        before(async () => {
            redBlackTree = (await redBlackTreeTester()).redBlackTreeTester;
        });

        const generateTests = (description: string, numberOfNodes: number, insertedNodes: bigint[], beforeAction?: () => Promise<void>) => {
            describe(description, () => {
                let blockSnapshot: SnapshotRestorer;
                let localSnapshot: SnapshotRestorer;

                before(async () => {
                    if (snapshot) {
                        await snapshot.restore();
                    }
                    blockSnapshot = await takeSnapshot();
                    if (beforeAction) {
                        await beforeAction();
                    }
                    snapshot = await takeSnapshot();
                    localSnapshot = snapshot;
                });

                beforeEach(async () => {
                    if (snapshot.snapshotId === localSnapshot.snapshotId) {
                        await snapshot.restore();
                        snapshot = await takeSnapshot();
                        localSnapshot = snapshot;
                    }
                });

                after(async () => {
                    await blockSnapshot.restore();
                    snapshot = await takeSnapshot();
                })

                if (numberOfNodes > 0) {
                    const nodeId = BigInt(numberOfNodes);
                    it (`should correctly insert node #${nodeId}`, async () => {
                        await redBlackTree.insertSmallest(nodeId, nodeId);
                        await redBlackTree.validate();
                        (await redBlackTree.getNodes())
                            .should.be.deep.equal([nodeId, ...insertedNodes]);
                    });

                    generateTests(`when node #${nodeId} was added (${[nodeId, ...insertedNodes]})`, numberOfNodes - 1, [nodeId, ...insertedNodes], async () => {
                         await redBlackTree.insertSmallest(nodeId, nodeId);
                    });
                }

                for (const removedNode of insertedNodes) {
                    const nodesAfterRemoval = insertedNodes.filter((node) => node !== removedNode);

                    it(`should correctly remove node #${removedNode}`, async () => {
                        await redBlackTree.remove(removedNode);
                        await redBlackTree.validate();
                        (await redBlackTree.getNodes())
                            .should.be.deep.equal(nodesAfterRemoval);
                    });

                    generateTests(`when node #${removedNode} was removed (${nodesAfterRemoval})`, numberOfNodes, nodesAfterRemoval, async () => {
                        await redBlackTree.remove(removedNode);
                    });
                }
            });
        }

        generateTests("when there are no nodes", maxN, []);
    });

    describe("random tests", () => {
        let redBlackTree: RedBlackTreeTester;
        const insertedNodes = new Set<bigint>();
        let nextNodeId = 1n;
        const MAX_AVERAGE_SIZE = 10;
        const NUMBER_OF_ITERATIONS = 200;

        before(async () => {
            redBlackTree = (await redBlackTreeTester()).redBlackTreeTester;
        });

        for (let averageSize = 1; averageSize <= MAX_AVERAGE_SIZE; ++averageSize) {
            it(`should work correctly with average size ${averageSize}`, async () => {
                for (let iteration = 0; iteration < NUMBER_OF_ITERATIONS; ++iteration) {
                    let addProbability = 0.6;
                    if (insertedNodes.size > averageSize) {
                        addProbability = 1 - addProbability;
                    }
                    if (insertedNodes.size === 0 || Math.random() < addProbability) {
                        // add node
                        const nodeId = nextNodeId++;
                        insertedNodes.add(nodeId);
                        await redBlackTree.insertSmallest(nodeId, nodeId);
                        await redBlackTree.validate();
                        Array.from(await redBlackTree.getNodes())
                            .should.have.members(Array.from(insertedNodes));
                    } else {
                        // remove node
                        const nodeId = _.sample(Array.from(insertedNodes))!;
                        insertedNodes.delete(nodeId);
                        await redBlackTree.remove(nodeId);
                        await redBlackTree.validate();
                        Array.from(await redBlackTree.getNodes())
                            .should.have.members(Array.from(insertedNodes));
                    }

                    if (insertedNodes.size === 0) {
                        nextNodeId = 1n;
                    }
                }
            });
        }
    });

    describe("test cases", () => {
        let snapshot: SnapshotRestorer;
        let redBlackTree: RedBlackTreeTester;

        before(async () => {
            redBlackTree = (await redBlackTreeTester()).redBlackTreeTester;
        });

        beforeEach(async () => {
            if (snapshot) {
                await snapshot.restore();
            }
            snapshot = await takeSnapshot();
        });

        it("insert 2 nodes", async () => {
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.validate();
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();
        });

        it("should insert and remove 2 nodes", async () => {
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.validate();
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();
            await redBlackTree.remove(2);
            await redBlackTree.validate();
            await redBlackTree.remove(1);
            await redBlackTree.validate();
        });

        it("should remove node in the middle", async () => {
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();

            await redBlackTree.remove(2);
            await redBlackTree.validate();

            await redBlackTree.remove(1);
            await redBlackTree.validate();
        });

        it("should remove node at the end", async () => {
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();

            await redBlackTree.remove(2);
            await redBlackTree.validate();

            await redBlackTree.remove(3);
            await redBlackTree.validate();
        });

        it("should insert 4 nodes", async () => {
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();
        });

        it("should remove biggest of 4 nodes", async () => {
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();

            await redBlackTree.remove(4);
            await redBlackTree.validate();
        });

        it("should remove smallest of 4 nodes", async () => {
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();

            await redBlackTree.remove(1);
            await redBlackTree.validate();

            await redBlackTree.remove(2);
            await redBlackTree.validate();
        });

        it("should allow to insert 5 nodes", async () => {
            await redBlackTree.insertSmallest(5, 5);
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();
        });

        it("should biggest of 6 nodes", async () => {
            await redBlackTree.insertSmallest(6, 6);
            await redBlackTree.insertSmallest(5, 5);
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();

            await redBlackTree.remove(6);
            await redBlackTree.validate();
        });

        it("should remove from the middle and from the end", async () => {
            await redBlackTree.insertSmallest(7, 7);
            await redBlackTree.insertSmallest(6, 6);
            await redBlackTree.insertSmallest(5, 5);
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.validate();

            await redBlackTree.remove(5);
            await redBlackTree.validate();

            await redBlackTree.remove(7);
            await redBlackTree.validate();
        });

        it("should remove black leaf and fix black height multiple times", async () => {
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.insertSmallest(5, 5);
            await redBlackTree.insertSmallest(6, 6);
            await redBlackTree.insertSmallest(7, 7);
            await redBlackTree.insertSmallest(8, 8);
            await redBlackTree.insertSmallest(9, 9);
            await redBlackTree.insertSmallest(10, 10);
            await redBlackTree.validate();

            await redBlackTree.remove(3);
            await redBlackTree.validate();
        });

        it("should fix height with black parent red sibling and straight red of red nephew", async () => {
            await redBlackTree.insertSmallest(1, 1);
            await redBlackTree.insertSmallest(102, 102);
            await redBlackTree.insertSmallest(103, 103);
            await redBlackTree.insertSmallest(104, 104);
            await redBlackTree.insertSmallest(5, 5);
            await redBlackTree.insertSmallest(6, 6);
            await redBlackTree.insertSmallest(7, 7);
            await redBlackTree.insertSmallest(8, 8);
            await redBlackTree.insertSmallest(9, 9);
            await redBlackTree.insertSmallest(10, 10);
            await redBlackTree.insertSmallest(55, 55);
            await redBlackTree.remove(6);
            await redBlackTree.insertSmallest(2, 2);
            await redBlackTree.remove(5);
            await redBlackTree.insertSmallest(58, 58);
            await redBlackTree.insertSmallest(3, 3);
            await redBlackTree.remove(7);
            await redBlackTree.remove(10);
            await redBlackTree.insertSmallest(60, 60);
            await redBlackTree.remove(103);
            await redBlackTree.insertSmallest(61, 61);
            await redBlackTree.remove(55);
            await redBlackTree.remove(8);
            await redBlackTree.insertSmallest(62, 62);
            await redBlackTree.remove(104);
            await redBlackTree.insertSmallest(63, 63);
            await redBlackTree.insertSmallest(4, 4);
            await redBlackTree.remove(61);
            await redBlackTree.remove(102);
            await redBlackTree.remove(63);
            await redBlackTree.remove(62);
            await redBlackTree.validate();

            await redBlackTree.remove(4);
            await redBlackTree.validate();
        });
    });
});
