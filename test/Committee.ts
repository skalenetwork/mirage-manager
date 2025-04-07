import chai from "chai";
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
        nextCommittee.startingTimestamp.should.be.lessThan(2n ** 256n - 1n);
        nextCommittee.startingTimestamp.should.be.greaterThan((await ethers.provider.getBlock("latest"))?.timestamp);
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
});
