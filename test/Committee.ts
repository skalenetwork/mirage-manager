import _, { round } from "lodash";
import seedrandom from 'seedrandom';
import chai, { assert, expect } from "chai";
import {
    cleanDeployment,
    sendHeartbeat,
    stakedNodes,
    whitelistedAndStakedAndHealthyNodes,
    whitelistedAndStakedNodes,
    whitelistedNodes
} from "./tools/fixtures";
import { ethers } from "hardhat";
import { runDkg } from "./tools/dkg";
import { skipTime } from "./tools/time";

chai.should();

const calculateProbabilityOfBeingSelectedToCommittee = (weights: Map<bigint, number>, committeeSize: number) => {
    const probabilities = new Map<bigint, number>();
    if (committeeSize < 1 || committeeSize > weights.size) {
        for (const node of weights.keys()) {
            probabilities.set(node, 0);
        }
        return probabilities;
    }
    if (committeeSize === weights.size) {
        for (const node of weights.keys()) {
            probabilities.set(node, 1);
        }
        return probabilities;
    }
    const totalWeight = _.sum([...weights.values()]);

    for (const [selectedNode, weight] of weights.entries()) {
        const probability = weight / totalWeight;
        const nextWeights = new Map(weights);
        nextWeights.delete(selectedNode);
        const nextProbabilities = calculateProbabilityOfBeingSelectedToCommittee(nextWeights, committeeSize - 1);
        for (const node of weights.keys()) {
            if (node === selectedNode) {
                probabilities.set(node, probability + (probabilities.get(node) ?? 0) );
            } else {
                probabilities.set(node, probability * (nextProbabilities.get(node) ?? 0) + (probabilities.get(node) ?? 0) );
            }
        }
    }
    return probabilities;
}

const normalize = (counts: Map<bigint, number>, total?: number) => {
    const result = new Map<bigint, number>();
    const _total = total ?? _.sum([...counts.values()]);
    for (const [key, value] of counts.entries()) {
        result.set(key, value / _total);
    }
    return result;
};

describe("Committee", () => {

    it("should allow contract owner to set version", async () => {
        const {committee} = await cleanDeployment();
        const version = await committee.version();
        expect(version).to.not.be.eql("");
        const newVersion = "mirage-mock-version";
        await committee.setVersion(newVersion);
        expect(newVersion).to.be.eql(await committee.version());
        const [, hacker] = await ethers.getSigners();

        await committee.connect(hacker).setVersion("I hacked you")
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");

        expect(newVersion).to.be.eql(await committee.version());
    });

    it("should not allow anyone to start committee rotation", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await whitelistedAndStakedAndHealthyNodes();
        await committee.connect(hacker).select()
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should select committee", async function () {
        this.timeout(600000); // 10 minutes timeout. DKG requires a lot of time
        const {committee, dkg, nodesData} = await whitelistedAndStakedAndHealthyNodes();
        const activeCommitteeIndex = await committee.getActiveCommitteeIndex();
        const nextCommitteeIndex = activeCommitteeIndex + 1n;

        await committee.select();

        let nextCommittee = await committee.getCommittee(nextCommitteeIndex);
        nextCommittee.dkg.should.not.be.equal(0n);
        nextCommittee.startingTimestamp.should.be.equal(2n ** 256n - 1n);
        nextCommittee.nodes.length.should.be.equal(await committee.committeeSize());

        await runDkg(dkg, nodesData, nextCommittee.dkg);

        nextCommittee = await committee.getCommittee(nextCommitteeIndex);
        const lastTransactionTimestamp = (await ethers.provider.getBlock("latest"))?.timestamp;
        assert(lastTransactionTimestamp);
        nextCommittee.startingTimestamp.should.be.equal(
            BigInt(lastTransactionTimestamp) + (await committee.transitionDelay())
        );
        nextCommittee.commonPublicKey.x.a.should.not.be.equal(0n);
        nextCommittee.commonPublicKey.x.b.should.not.be.equal(0n);
        nextCommittee.commonPublicKey.y.a.should.not.be.equal(0n);
        nextCommittee.commonPublicKey.y.b.should.not.be.equal(0n);
    });

    it("should not allow anyone to set dkg contract", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await cleanDeployment();
        await committee.connect(hacker).setDkg(hacker)
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should not allow anyone to set rng contract", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await cleanDeployment();
        await committee.connect(hacker).setRNG(hacker)
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should not allow anyone to set nodes contract", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await cleanDeployment();
        await committee.connect(hacker).setNodes(hacker)
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should not allow anyone to set status contract", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await cleanDeployment();
        await committee.connect(hacker).setStatus(hacker)
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should not allow anyone to call successful dkg", async () => {
        const {committee} = await cleanDeployment();
        await committee.processSuccessfulDkg(0xd2n)
            .should.be.revertedWithCustomError(committee, "SenderIsNotDkg");
    });

    it("should not allow anyone to set committee", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await cleanDeployment();
        await committee.connect(hacker).setCommitteeSize(0xd2n)
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should not allow anyone to set transition delay", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await cleanDeployment();
        await committee.connect(hacker).setTransitionDelay(0xd2n)
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should set rng contract", async () => {
        const {committee} = await whitelistedAndStakedAndHealthyNodes();
        const rng = await ethers.deployContract("MockRNG");
        await rng.waitForDeployment();

        // This automaticaly tests if call to random is succeeded
        await committee.setRNG(rng);

        expect(await committee.rng()).to.equal(await rng.getAddress());
    });

    it("should set committee size", async () => {
        const {committee} = await whitelistedAndStakedAndHealthyNodes();
        const newSize = 13n;

        await committee.setCommitteeSize(newSize);

        (await committee.committeeSize()).should.be.equal(newSize);

        await committee.select();

        const nextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);
        nextCommittee.nodes.length.should.be.equal(newSize);
    });

    it("should set transition delay", async () => {
        const {committee, dkg, nodesData} = await whitelistedAndStakedAndHealthyNodes();
        const activeCommitteeIndex = await committee.getActiveCommitteeIndex();
        const nextCommitteeIndex = activeCommitteeIndex + 1n;
        const newTransitionDelay = 0xd2n;
        await committee.setCommitteeSize(2); // to save resources

        await committee.setTransitionDelay(newTransitionDelay);
        await committee.select();

        let nextCommittee = await committee.getCommittee(nextCommitteeIndex);

        await runDkg(dkg, nodesData, nextCommittee.dkg);

        (await committee.transitionDelay()).should.be.equal(newTransitionDelay);
        nextCommittee = await committee.getCommittee(nextCommitteeIndex);
        nextCommittee.startingTimestamp.should.be.lessThan(2n ** 256n - 1n);
        const lastTransactionTimestamp = (await ethers.provider.getBlock("latest"))?.timestamp;
        assert(lastTransactionTimestamp);
        nextCommittee.startingTimestamp.should.be.equal(
            BigInt(lastTransactionTimestamp) + newTransitionDelay
        );
    });

    it("should check if a node in the committee or will be there soon", async function () {
        // TODO: this test does not fit standard timelimit with old nodejs
        // remove this line after stop using nodejs 20
        this.timeout(50000); // slightly increase timeout for older nodejs
        const {committee, dkg, nodesData, status} = await whitelistedAndStakedAndHealthyNodes();
        await committee.setCommitteeSize(5);

        await committee.select();
        await runDkg(
            dkg,
            nodesData,
            (await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n)).dkg
        );
        await skipTime(await committee.transitionDelay());
        for (const node of nodesData) {
            await status.connect(node.wallet).alive();
        }
        await committee.select();

        const activeCommitteeIndex = await committee.getActiveCommitteeIndex();
        const nextCommitteeIndex = activeCommitteeIndex + 1n;

        const activeCommittee = await committee.getCommittee(activeCommitteeIndex);
        const nextCommittee = await committee.getCommittee(nextCommitteeIndex);

        for (const node of nodesData) {
            expect((await committee.isNodeInCurrentOrNextCommittee(node.id)))
                .to.be.equal(
                    activeCommittee.nodes.includes(BigInt(node.id))
                    || nextCommittee.nodes.includes(BigInt(node.id))
                );
        }
    });

    it("should select only whitelisted nodes to the committee", async () => {
        seedrandom('d2-d2', { global: true });
        const _lodash = _.runInContext();
        const {committee, nodesData, status} = await stakedNodes();
        const whitelistedNodes = _lodash.sampleSize(nodesData, Number(await committee.committeeSize()));
        for (const node of whitelistedNodes) {
            await status.whitelistNode(node.id);
        }
        await sendHeartbeat(status, nodesData);

        await committee.select();
        const nextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);

        for (const node of nodesData) {
            if (whitelistedNodes.includes(node)) {
                expect(nextCommittee.nodes).to.include(node.id);
            } else {
                expect(nextCommittee.nodes).to.not.include(node.id);
            }
        }
    });

    it("should select only healthy nodes to the committee", async () => {
        seedrandom('d2-d2', { global: true });
        const _lodash = _.runInContext();
        const {committee, nodesData, status} = await whitelistedAndStakedNodes();
        const healthyNodes = _lodash.sampleSize(nodesData, Number(await committee.committeeSize()));
        for (const node of healthyNodes) {
            await status.connect(node.wallet).alive();
        }

        await committee.select();
        const nextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);

        for (const node of nodesData) {
            if (healthyNodes.includes(node)) {
                expect(nextCommittee.nodes).to.include(node.id);
            } else {
                expect(nextCommittee.nodes).to.not.include(node.id);
            }
        }
    });

    it("should restart committee selection", async () => {
        const {committee, dkg, nodesData} = await whitelistedAndStakedAndHealthyNodes();
        await committee.setCommitteeSize(5);

        await committee.select();
        const badNextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);

        await committee.select();
        const goodNextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);

        await runDkg(dkg, nodesData, badNextCommittee.dkg);
        await runDkg(dkg, nodesData, goodNextCommittee.dkg);

        await skipTime(await committee.transitionDelay());

        for (const node of nodesData) {
            expect(await committee.isNodeInCurrentOrNextCommittee(node.id))
                .to.be.equal(goodNextCommittee.nodes.includes(BigInt(node.id)));
        }
    });

    it("should select nodes to the committee accordingly to its stake", async function () {
        // This test can consume a lot of time because it's random.
        // To speed up the test decrease tolerance or committee size/nodes number
        // On local machine it was checked that the accuracy is less then 1% for 5 nodes committee
        this.timeout(180000); // 3 minutes for ~112 iterations

        const committeeSize = 2;
        const stakedNodesNumber = 5;
        const maxIterations = 200;
        const tolerance = 0.1; // 10%
        const stakeAmounts = new Map(
            _.range(stakedNodesNumber).map((value, index) => [BigInt(index + 1), Math.log(value + 2)])
        );

        const {committee, staking, status, nodesData} = await whitelistedNodes();
        await committee.setCommitteeSize(committeeSize);
        for (const [nodeId, stake] of stakeAmounts.entries()) {
            await staking.stake(nodeId, {value: ethers.parseEther(stake.toString())});
        }
        await sendHeartbeat(status, nodesData);

        const weights = new Map(stakeAmounts);
        const probabilities = calculateProbabilityOfBeingSelectedToCommittee(weights, committeeSize);
        const stakedNodes = [...stakeAmounts.keys()];
        const counts = new Map<bigint, number>(stakedNodes.map((nodeId) => [nodeId, 0]));
        let ratioIsGood = false;
        for (let iteration = 1; !ratioIsGood ; ++iteration) {
            await committee.select();
            const nextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);
            for (const nodeId of nextCommittee.nodes) {
                counts.set(nodeId, (counts.get(nodeId) || 0) + 1);
            }
            await sendHeartbeat(status, nodesData.filter((node) => nextCommittee.nodes.includes(BigInt(node.id))));
            await status.connect(nodesData.find((node) => node.id === stakedNodes[iteration % stakedNodes.length])!.wallet).alive();

            const frequencies = normalize(counts, iteration);

            ratioIsGood = true;
            for (const [node, frequency] of frequencies.entries()) {
                const probability = probabilities.get(node) ?? 0;
                const error = Math.abs(frequency - probability);
                if (error > tolerance) {
                    ratioIsGood = false;
                }
            }

            if (iteration >= maxIterations) {
                probabilities.should.be.equal(
                    frequencies,
                    `\nFrequencies:\t${
                        [...frequencies.values()].map((value) => round(value, 2))
                    }\nProbabilities:\t${
                        [...probabilities.values()].map((value) => round(value, 2))
                    }\n`);
                break;
            }
        }
    });

    it("should emit proper error when there are eligible nodes but all of them are not healthy", async () => {
        const {committee, status} = await whitelistedAndStakedAndHealthyNodes();
        await skipTime(await status.heartbeatInterval());
        await committee.select()
            .should.be.revertedWithCustomError(committee, "TooFewCandidates")
            .withArgs(await committee.committeeSize(), 0);
    });
});
