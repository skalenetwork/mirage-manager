import {
    loadFixture
} from "@nomicfoundation/hardhat-network-helpers";
import {splayTreeTester} from "../tools/testingFixtures";
import chai from "chai";
import _ from 'lodash';
import {Permutation} from 'js-combinatorics';
import { SplayTreeTester } from "../../typechain-types";

chai.should();

describe("SplayTree", () => {
    const maxN = 5;
    const nValues = _.range(1, maxN + 1);

    nValues.forEach((n) => {

        const buildTree = async () => {
            const {splayTreeTester: splayTree} = await splayTreeTester();
            for (let i = n; i > 0; --i) {
                await splayTree.insertSmallest(i, i);
            }
            return {splayTree};
        }

        const nodes = _.range(1, n + 1).map((i) => BigInt(i));

        const checkSplayTree = async (splayTree: SplayTreeTester, subtreeNodes: bigint[] = nodes, node?: bigint, parent: bigint = 0n) => {
            if (!node) {
                node = await splayTree.root();
            }
            subtreeNodes.should.contain(node);
            const nodeData = await splayTree.tree(node);
            nodeData.id.should.be.equal(node);
            nodeData.parent.should.be.equal(parent);
            if (nodeData.left) {
                await checkSplayTree(
                    splayTree,
                    subtreeNodes.slice(0, subtreeNodes.indexOf(node)),
                    nodeData.left,
                    node);
            } else {
                node.should.be.equal(subtreeNodes[0], `Node is not leftmost. Node: ${node}, subtreeNodes: ${subtreeNodes}`);
            }
            if (nodeData.right) {
                await checkSplayTree(
                    splayTree,
                    subtreeNodes.slice(subtreeNodes.indexOf(node) + 1, subtreeNodes.length),
                    nodeData.right,
                    node);
            } else {
                node.should.be.equal(subtreeNodes[subtreeNodes.length - 1], "Node is not rightmost");
            }
            nodeData.totalWeight.should.be.equal(_.sum(subtreeNodes));
        };

        describe(`when ${n} elements are inserted`, () => {
            for (const permutation of new Permutation(nodes)) {
                it(`should be valid after applying splay in ${permutation} order`, async () => {
                    const {splayTree} = await loadFixture(buildTree);
                    for (const node of permutation) {
                        await splayTree.splay(node);
                        await checkSplayTree(splayTree);
                    }
                });
            }
        });
    });
});
