import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import {splayTreeTester} from "../tools/testingFixtures";
import chai from "chai";
import _ from 'lodash';
import {Permutation} from 'js-combinatorics';
import { SplayTreeTester } from "../../typechain-types";

chai.should();

const buildTree = async (n: number) => {
    const {splayTreeTester: splayTree} = await splayTreeTester();
    for (let i = n; i > 0; --i) {
        await splayTree.insertSmallest(i, i);
    }
    return {splayTree};
}

const checkSplayTree = async (splayTree: SplayTreeTester, orderedValues: bigint[], node?: bigint, parent: bigint = 0n) => {
    if (!node) {
        node = await splayTree.root();
    }
    orderedValues.should.contain(node);
    const nodeData = await splayTree.tree(node);
    nodeData.id.should.be.equal(node);
    nodeData.parent.should.be.equal(parent, "Incorrect parent");
    if (nodeData.left) {
        await checkSplayTree(
            splayTree,
            orderedValues.slice(0, orderedValues.indexOf(node)),
            nodeData.left,
            node);
    } else {
        node.should.be.equal(orderedValues[0], `Node is not leftmost. Node: ${node}, subtreeNodes: ${orderedValues}`);
    }
    if (nodeData.right) {
        await checkSplayTree(
            splayTree,
            orderedValues.slice(orderedValues.indexOf(node) + 1, orderedValues.length),
            nodeData.right,
            node);
    } else {
        node.should.be.equal(orderedValues[orderedValues.length - 1], "Node is not rightmost");
    }
    nodeData.totalWeight.should.be.equal(_.sum(orderedValues));
};

describe("SplayTree", () => {
    describe("stress tests", () => {
        const maxN = 5;
        const nValues = _.range(1, maxN + 1);

        nValues.forEach((n) => {

            const nodes = _.range(1, n + 1).map((i) => BigInt(i));

            const buildTreeFixture = async () => {
                return buildTree(n);
            }

            describe(`when ${n} elements are inserted`, () => {
                for (const permutation of new Permutation(nodes)) {
                    it(`should be valid after applying splay in ${permutation} order`, async () => {
                        const {splayTree} = await loadFixture(buildTreeFixture);
                        for (const node of permutation) {
                            await splayTree.splay(node);
                            await checkSplayTree(splayTree, nodes);
                        }
                    });
                }
            });
        });
    });
    describe("test cases", () => {
        const n = 10;
        const nodes = _.range(1, n + 1).map((i) => BigInt(i));

        const buildTreeFixture = async () => {
            return buildTree(n);
        }

        it("should splay maximum after removing element in the middle", async () => {
            const {splayTree} = await loadFixture(buildTreeFixture);
            await splayTree.splay(n);
            await checkSplayTree(splayTree, nodes);
            const removingNode = Math.floor(n / 2);
            await splayTree.remove(removingNode);
            const changedNodes = nodes.filter((node) => node !== BigInt(removingNode));
            await checkSplayTree(splayTree, changedNodes);
            await splayTree.splay(n);
            await checkSplayTree(splayTree, changedNodes);
        });

        it("should revert if trying to splay non-existing node", async () => {
            const {splayTree} = await loadFixture(buildTreeFixture);
            await splayTree.splay(await splayTree.NULL())
                .should.be.revertedWithCustomError(splayTree, "SplayOnNull");
        });

        it("should not set anything to the node with NULL id when inserting to empty tree", async () => {
            const {splayTreeTester: splayTree} = await splayTreeTester();
            await splayTree.insertSmallest(1, 1);
            const node = await splayTree.tree(await splayTree.NULL());
            node.id.should.be.equal(await splayTree.NULL());
            node.parent.should.be.equal(await splayTree.NULL());
            node.left.should.be.equal(await splayTree.NULL());
            node.right.should.be.equal(await splayTree.NULL());
            node.totalWeight.should.be.equal(0n);
        });
    });
});
