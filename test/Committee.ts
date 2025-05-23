import _ from "lodash";
import seedrandom from 'seedrandom';
import chai, { assert, expect } from "chai";
import { cleanDeployment, nodesAreRegisteredAndHeartbeatIsSent, nodesRegistered, nodesRegisteredButNotWhitelisted } from "./tools/fixtures";
import { ethers } from "hardhat";
import { runDkg } from "./tools/dkg";
import { skipTime } from "./tools/time";

chai.should();

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
        const {committee} = await nodesAreRegisteredAndHeartbeatIsSent();
        await committee.connect(hacker).select()
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should select committee", async function () {
        this.timeout(600000); // 10 minutes timeout. DKG requires a lot of time
        const {committee, dkg, nodesData} = await nodesAreRegisteredAndHeartbeatIsSent();
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

    it("should set committee size", async () => {
        const {committee} = await nodesAreRegisteredAndHeartbeatIsSent();
        const newSize = 13n;

        await committee.setCommitteeSize(newSize);

        (await committee.committeeSize()).should.be.equal(newSize);

        await committee.select();

        const nextCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex() + 1n);
        nextCommittee.nodes.length.should.be.equal(newSize);
    });

    it("should set transition delay", async () => {
        const {committee, dkg, nodesData} = await nodesAreRegisteredAndHeartbeatIsSent();
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
        const {committee, dkg, nodesData, status} = await nodesAreRegisteredAndHeartbeatIsSent();
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
        const {committee, nodesData, status} = await nodesRegisteredButNotWhitelisted();
        const whitelistedNodes = _lodash.sampleSize(nodesData, Number(await committee.committeeSize()));
        for (const node of whitelistedNodes) {
            await status.whitelistNode(node.id);
        }
        for (const node of nodesData) {
            await status.connect(node.wallet).alive();
        }

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
        const {committee, nodesData, status} = await nodesRegistered();
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
        const {committee, dkg, nodesData} = await nodesAreRegisteredAndHeartbeatIsSent();
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
});
