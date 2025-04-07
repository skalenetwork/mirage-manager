import chai, { assert } from "chai";
import { cleanDeployment, nodesAreRegisteredAndHeartbeatIsSent } from "./fixtures";
import { ethers } from "hardhat";
import { runDkg } from "./dkg/DKG";

chai.should();

describe("Committee", () => {
    it("should not allow anyone to start committee rotation", async () => {
        const [, hacker] = await ethers.getSigners();
        const {committee} = await nodesAreRegisteredAndHeartbeatIsSent();
        await committee.connect(hacker).select()
            .should.be.revertedWithCustomError(committee, "AccessManagedUnauthorized");
    });

    it("should select committee", async () => {
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
});
