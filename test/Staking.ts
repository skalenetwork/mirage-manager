import chai, { assert, expect } from "chai";
import { registeredOnlyNodes, sendHeartbeat, stakedNodes, whitelistedNodes } from "./tools/fixtures";
import { ethers } from "hardhat";
import { zip } from "lodash";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { skipTime } from "./tools/time";

chai.should();

const sumBigInt = (arr: bigint[]) => arr.reduce((acc, val) => acc + val, 0n);

const ALLOWED_ERROR = 10n**9n; // 1 wei tolerance for rounding errors
const N_PRECISION_BITS = 80;
const PRECISION = 1n << BigInt(N_PRECISION_BITS); // 1 << 80
const HUGE_AMOUNT_OF_FAIR = 10n**38n // 100 Billions of FAIR in wei
const ONE_DAY_IN_SECONDS = 24 * 60 * 60;

describe("Staking", () => {

    it("should allow holder to stake", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [,user] = await ethers.getSigners();
        const amount = ethers.parseEther("1");
        const node = nodesData[0].id;
        await staking.connect(user).stake(node, {value: amount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount);
        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount);

        // No heartbeats, so node was not set as disabled yet even thought it's not healthy or whitelisted
        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(1n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([user.address]);

    });

    it("should distribute rewards proportionally to stake", async () => {
        const {staking, status, nodesData } = await whitelistedNodes();
        const [owner, user1, user2] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const reward = ethers.parseEther("5");
        const node = nodesData[0].id;

        // Set fee rate to 0 for proportional distribution
        await staking.connect(nodesData[0].wallet).setFeeRate(0);

        await staking.connect(user1).stake(node, {value: amount1});
        await staking.connect(user2).stake(node, {value: amount2});
        await sendHeartbeat(status, [nodesData[0]]); // Enable the node

        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount1 + amount2);
        // Pay reward
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.connect(user1).getStakedAmount())
            .should.be.equal(amount1 + reward * amount1 / (amount1 + amount2));
        (await staking.connect(user2).getStakedAmount())
            .should.be.equal(amount2 + reward * amount2 / (amount1 + amount2));

        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount1 + amount2 + reward);

        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(2n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([user1.address, user2.address]);
    });

    it("should be able to stake to multiple nodes", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [, user] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const [node1, node2] = [nodesData[0].id, nodesData[1].id];

        await staking.connect(user).stake(node1, {value: amount1});
        await staking.connect(user).stake(node2, {value: amount2});

        (await staking.connect(user).getStakedNodes())
            .map(BigInt)
            .should.have.members([node1, node2]);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount1 + amount2);
        (await staking.connect(user).getStakedToNodeAmount(node1))
            .should.be.equal(amount1);
        (await staking.connect(user).getStakedToNodeAmount(node2))
            .should.be.equal(amount2);

        expect(await staking.getDelegatorsToNodeCount(node1)).to.be.eql(1n);
        expect(await staking.getDelegatorsToNodeCount(node2)).to.be.eql(1n);

        expect(await staking.getDelegatorsToNode(node1)).to.be.eql([user.address]);
        expect(await staking.getDelegatorsToNode(node2)).to.be.eql([user.address]);
    });

    it("should calculate rewards correctly when inflated by consensus", async () => {
        const {staking, status, nodesData } = await whitelistedNodes();
        const [, user1, user2] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const reward = ethers.parseEther("5");
        const node = nodesData[0].id;

        await staking.connect(user1).stake(node, {value: amount1});
        await staking.connect(user2).stake(node, {value: amount2});

        await sendHeartbeat(status, [nodesData[0]]);
        expect(await staking.isNodeEnabled(node)).to.be.eql(true);

        // 80% to node and 20% to hole network (but there's just 1 staked node)
        await setBalance(await staking.getAddress(), await ethers.provider.getBalance(staking) + reward * 20n / 100n);
        await setBalance(await staking.getRewardWallet(node), reward * 80n / 100n);

        expect(await staking.getEarnedFeeAmount(node)).to.be.eql(reward);

        expect(await staking.getStakedToNodeAmountFor(node, user1)).to.be.eql(amount1);
        expect(await staking.getStakedToNodeAmountFor(node, user2)).to.be.eql(amount2);

        // Set fee rate to 50%
        await staking.connect(nodesData[0].wallet).setFeeRate(500);

        expect(await staking.getEarnedFeeAmount(node)).to.be.eql(reward);

        // Owner has 5 = 50%
        // user1 has 2 = 20%
        // user2 has 3 = 30%

        await setBalance(await staking.getAddress(), await ethers.provider.getBalance(staking) + reward);

        const earnedByFee = reward / 2n; //50%
        const forDelegators = reward - earnedByFee

        const earnedByStakeNodeOwner = forDelegators * 50n / 100n; // owner had 50% of stake
        const earnedByStakeUser1 = forDelegators * 20n / 100n //user1 had 20%
        const earnedByStakeUser2 = forDelegators * 30n / 100n //user2 had 30%
        expect(await staking.getEarnedFeeAmount(node)).to.be.eql(reward + earnedByFee + earnedByStakeNodeOwner);
        expect(await staking.getStakedToNodeAmountFor(node, user1)).to.eql(amount1 + earnedByStakeUser1);
        expect(await staking.getStakedToNodeAmountFor(node, user2)).to.eql(amount2 + earnedByStakeUser2);
    });

    it("should be possible to retrieve", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [,user] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("1");
        const node = nodesData[22].id;

        await staking.connect(user).stake(node, {value: initialAmount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);
        expect(await staking.getNodeTotalStake(node)).to.be.eql(initialAmount);

        await staking.connect(user).requestRetrieve(node, amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount - amount);

        expect(await staking.getNodeTotalStake(node)).to.be.eql(initialAmount - amount);

        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(1n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([user.address]);

        await staking.connect(user).requestRetrieve(node, initialAmount - amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(0n);

        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(0n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([]);

        await skipTime(ONE_DAY_IN_SECONDS);

        await expect(staking.connect(user).claimRequest(0)).to.changeEtherBalance(user, amount);
        await expect(staking.connect(user).claimRequest(1)).to.changeEtherBalance(user, initialAmount - amount);

    });

    it("should be 'safe' to retrieve by id and index, and have no request limit", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [,user] = await ethers.getSigners();

        const amount = 5n; // 5 wei
        const node = nodesData[22].id;
        const numRetrieve = 100n;
        const initialAmount = amount * (numRetrieve + 2n)
        await staking.connect(user).stake(node, {value: initialAmount});
        for (let index = 0; index < numRetrieve; index++) {
            await staking.connect(user).requestRetrieve(node, amount);
        }
        expect(await staking.getExitRequestsCountFor(user)).to.be.eql(numRetrieve);
        expect(await staking.getTotalInExitQueue()).to.be.eql(numRetrieve * amount);
        expect(await staking.getTotalInExitQueueFor(user)).to.be.eql(numRetrieve * amount);

        await expect(staking.getExitRequestAt(user, numRetrieve - 1n)).to.not.be.reverted;

        await expect(staking.getExitRequestAt(user, numRetrieve)).to.be.revertedWithCustomError(staking, "UserDoesNotHaveRequestAt");

        await skipTime(ONE_DAY_IN_SECONDS);

        for (let index = 0; index < numRetrieve; index++) {
            const requestAt0 = await staking.getExitRequestAt(user, 0);
            const unlocked = await staking.getUnlockedExitRequestFor(user, 0);
            // they are the same because are all unlocked
            expect(unlocked.requestId).to.be.eql(requestAt0.requestId);
            await staking.connect(user).claimRequest(requestAt0.requestId);
        }
        await expect(staking.getExitRequestAt(user, 0)).to.be.revertedWithCustomError(staking, "UserDoesNotHaveRequestAt");
    });

    it("should allow only allowed node owner to change allowed list", async () => {
        const {staking, nodesData, nodes} = await registeredOnlyNodes();
        const [,hacker] = await ethers.getSigners();
        const node = nodesData[22]; // not in the current committee

        // only node owner can add receivers
        await expect(staking.addAllowedReceiver(hacker.address)).to.be.revertedWithCustomError(nodes, "AddressIsNotAssignedToAnyNode");

        // node owner can register itself
        await expect(staking.connect(node.wallet).addAllowedReceiver(node.wallet)).to.emit(staking, "AllowedReceiverAdded");

        // node owner can remove itself
        await expect(staking.connect(node.wallet).removeAllowedReceiver(node.wallet))
        .to.emit(staking, "AllowedReceiverRemoved");

        await nodes.connect(node.wallet).deleteNode(node.id);

        // Should not allow changing allowed list after node deletion
        await staking.connect(node.wallet).removeAllowedReceiver(node.wallet).should.be.revertedWithCustomError(nodes, "AddressIsNotAssignedToAnyNode");
    });

    it("only authorized users should be able to claim, send or receive rewards", async () => {
        const {staking, nodesData, nodes} = await registeredOnlyNodes();
        const [,user, allowedReceiver] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("1");
        const node = nodesData[22]; // not in the current committee
        const feeRate = 500; // Yes, Eddie, half
        await staking.connect(node.wallet).setFeeRate(feeRate);
        await staking.setRetrievingDelay(0n); // immediately available
        await staking.connect(user).stake(node.id, {value: initialAmount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);

        // pay rewards to the node
        const rewardWallet = await staking.getRewardWallet(node.id);
        await setBalance(rewardWallet, amount);

        // Node has 0.5 FAIR to collect in Fees
        const tinyAmount = 10n;

        // Node owner can send fees to anyone if it has not set any allowed receiver
        await staking.connect(node.wallet).requestSendFees(user, tinyAmount);
        expect(await staking.connect(user).claimRequest(0)).to.changeEtherBalance(user, tinyAmount);

        // Node owner can always claim fees
        await staking.connect(node.wallet).requestFees(node.id, tinyAmount);
        expect(await staking.connect(node.wallet).claimRequest(1)).to.changeEtherBalance(node.wallet, tinyAmount);

        await expect(staking.connect(allowedReceiver).requestFees(node.id, tinyAmount)).to.be.revertedWithCustomError(staking, "NotAllowedToClaimRewards");

        await staking.connect(node.wallet).addAllowedReceiver(allowedReceiver);

        // Node owner can now only send fees to allowed receivers
        await expect(staking.connect(node.wallet).requestSendFees(user, tinyAmount)).to.be.revertedWithCustomError(staking, "NotAllowedToClaimRewards");

        // allowed receiver can claim fees
        await staking.connect(allowedReceiver).requestFees(node.id, tinyAmount);
        expect(await staking.connect(allowedReceiver).claimRequest(2)).to.changeEtherBalance(node.wallet, tinyAmount);


        // allowed receiver can receive fees
        await staking.connect(node.wallet).requestSendFees(allowedReceiver, tinyAmount);
        expect(await staking.connect(allowedReceiver).claimRequest(3)).to.changeEtherBalance(allowedReceiver, tinyAmount);


        // Node owner can always receive fees
        await staking.connect(node.wallet).requestSendFees(node.wallet, tinyAmount);
        expect(await staking.connect(node.wallet).claimRequest(4)).to.changeEtherBalance(node.wallet, tinyAmount);


        // allowed receivers cannot send fees, only claim
        await expect(staking.connect(allowedReceiver).requestSendFees(allowedReceiver, tinyAmount))
        .to.be.revertedWithCustomError(nodes, "AddressIsNotAssignedToAnyNode");

        // Node owner sends remaining fees to allowed receiver
        await staking.connect(node.wallet).requestSendAllFees(allowedReceiver);

        const lockedFees = await staking.connect(allowedReceiver).getMyTotalInExitQueue();
        expect(await staking.isRequestUnlocked(5)).to.be.eql(false);
        await staking.connect(node.wallet).removeAllowedReceiver(allowedReceiver);

        // new block was mined, timestamp updated, this fees are now unlocked because waiting time is 0 seconds
        const unlockedFees = (await staking.connect(allowedReceiver).getUnlockedExitRequestFor(allowedReceiver, 0)).amount;
        expect((await staking.connect(allowedReceiver).getUnlockedExitRequestFor(allowedReceiver, 0)).requestId).to.be.eql(5n);
        expect(unlockedFees).to.be.eql(lockedFees);

        // Not allowed receiver, but can still claim fees that were previously sent/assigned to it
        await staking.connect(allowedReceiver).claimRequest(5).should.changeEtherBalance(allowedReceiver, lockedFees);
    });

    it("should always respect retrieving delay", async () => {
        const {staking, nodesData, status} = await whitelistedNodes();
        const [,user] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("1");
        const node = nodesData[22];
        const feeRate = 500; // Yes, Eddie, half
        await staking.connect(node.wallet).setFeeRate(feeRate);
        //await staking.setRetrievingDelay(0n); // immediately available
        await staking.connect(user).stake(node.id, {value: initialAmount});
        await status.connect(node.wallet).alive(); // make node eligible
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);

        const tinyAmount = 10n;

        // pay some rewards
        await staking.connect(user).payReward(node.id, {value: amount});

        expect(await staking.getNodeShare(node.id)).to.be.eql(PRECISION * (initialAmount + amount));

        await staking.connect(user).requestRetrieve(node.id, tinyAmount);
        await staking.connect(node.wallet).requestFees(node.id, tinyAmount);

        expect(await staking.getNodeShare(node.id)).to.be.eql(PRECISION * (initialAmount + amount - tinyAmount*2n));


        expect(await staking.connect(user).getMyTotalInExitQueue()).to.be.eql(tinyAmount);
        expect(await staking.connect(node.wallet).getMyTotalInExitQueue()).to.be.eql(tinyAmount);
        expect(await staking.getTotalInExitQueue()).to.be.eql(2n * tinyAmount);

        await skipTime(ONE_DAY_IN_SECONDS - 10); // skip almost 1 day

        await expect(staking.getUnlockedExitRequestFor(user, 0)).to.be.revertedWithCustomError(staking, "ZeroUnlockedRequests");
        await expect(staking.getUnlockedExitRequestFor(node.wallet, 0)).to.be.revertedWithCustomError(staking, "ZeroUnlockedRequests");
        expect(await staking.getTotalInExitQueue()).to.be.eql(2n * tinyAmount);

        await expect(staking.connect(user).claimRequest(0)).to.be.revertedWithCustomError(staking, "RequestIsStillLocked");
        await expect(staking.connect(node.wallet).claimRequest(1)).to.be.revertedWithCustomError(staking, "RequestIsStillLocked");

        await skipTime(10); // skip 10 seconds

        expect((await staking.getUnlockedExitRequestFor(user, 0)).requestId).to.be.eql(0n)
        expect((await staking.getUnlockedExitRequestFor(node.wallet, 0)).requestId).to.be.eql(1n)

        await expect(staking.connect(user).claimRequest(0)).to.changeEtherBalance(user, tinyAmount);
        expect(await staking.getTotalInExitQueue()).to.be.eql(tinyAmount);

        await expect(staking.connect(user).claimRequest(0)).to.revertedWithCustomError(staking, "RequestDoesNotExist");
        await expect(staking.connect(user).claimRequest(1)).to.revertedWithCustomError(staking, "RequestDoesNotExistForUser");
        expect(await staking.getTotalInExitQueue()).to.be.eql(tinyAmount);

        await expect(staking.connect(node.wallet).claimRequest(1)).to.changeEtherBalance(node.wallet, tinyAmount);
        expect(await staking.getTotalInExitQueue()).to.be.eql(0n);

        // again but now we change the delay after the request
        await staking.connect(user).requestRetrieve(node.id, tinyAmount);
        await staking.connect(node.wallet).requestFees(node.id, tinyAmount);

        await staking.setRetrievingDelay(0); // 0 seconds delay

        // Will not affect previous created requests
        await expect(staking.getUnlockedExitRequestFor(user, 0)).to.be.revertedWithCustomError(staking, "ZeroUnlockedRequests");
        await expect(staking.getUnlockedExitRequestFor(node.wallet, 0)).to.be.revertedWithCustomError(staking, "ZeroUnlockedRequests");
        expect(await staking.getTotalInExitQueue()).to.be.eql(2n * tinyAmount);

        await expect(staking.connect(user).claimRequest(2)).to.be.revertedWithCustomError(staking, "RequestIsStillLocked");
        await expect(staking.connect(node.wallet).claimRequest(3)).to.be.revertedWithCustomError(staking, "RequestIsStillLocked");

        await skipTime(ONE_DAY_IN_SECONDS); // skip 1 day

        expect((await staking.getUnlockedExitRequestFor(user, 0)).requestId).to.be.eql(2n)
        expect((await staking.getUnlockedExitRequestFor(node.wallet, 0)).requestId).to.be.eql(3n)

        await expect(staking.connect(user).claimRequest(2)).to.changeEtherBalance(user, tinyAmount);
        expect(await staking.getTotalInExitQueue()).to.be.eql(tinyAmount);

        await expect(staking.connect(user).claimRequest(2)).to.revertedWithCustomError(staking, "RequestDoesNotExist");
        await expect(staking.connect(user).claimRequest(3)).to.revertedWithCustomError(staking, "RequestDoesNotExistForUser");
        expect(await staking.getTotalInExitQueue()).to.be.eql(tinyAmount);

        await expect(staking.connect(node.wallet).claimRequest(3)).to.changeEtherBalance(node.wallet, tinyAmount);
        expect(await staking.getTotalInExitQueue()).to.be.eql(0n);
    });

    it("should not be possible and needed to requestFees and send after node deletion", async () => {
        const {staking, nodesData, nodes, status} = await whitelistedNodes();
        const [,user] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("2");
        const node = nodesData[22]; // not in the current committee
        const feeRate = 500; // Yes, Eddie, half
        await staking.connect(node.wallet).setFeeRate(feeRate);
        await staking.connect(user).stake(node.id, {value: initialAmount});

        // Node should be eligible
        await status.connect(node.wallet).alive();

        expect(await staking.isNodeEnabled(node.id)).to.be.eql(true);

        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);

        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(initialAmount);
        expect(await staking.getDelegatorsToNodeCount(node.id)).to.be.eql(1n);
        expect(await staking.getDelegatorsToNode(node.id)).to.be.eql([user.address]);

        // missing balance in reward wallet from rewards
        const rewardWallet = await staking.getRewardWallet(node.id);
        await setBalance(rewardWallet, amount);

        expect(await staking.getEarnedFeeAmount(node.id)).to.be.eql(amount / 2n);
        // shall send fees to the node, request 0
        await nodes.connect(node.wallet).deleteNode(node.id);


        expect(await nodes.activeNodeExists(node.id)).to.be.eql(false);
        expect(await staking.isNodeEnabled(node.id)).to.be.eql(false);

        const fees = amount / 2n;
        expect(await staking.getEarnedFeeAmount(node.id)).to.be.eql(0n);
        // fees were sent to the node
        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(initialAmount + amount - fees);
        expect(await staking.getDelegatorsToNodeCount(node.id)).to.be.eql(1n);
        expect(await staking.getDelegatorsToNode(node.id)).to.be.eql([user.address]);

        await staking.connect(user).requestRetrieve(node.id, amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount - amount / 2n);

        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(initialAmount - amount / 2n);

        await staking.connect(user).requestRetrieve(node.id, initialAmount - amount / 2n);

        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(0n);
        expect(await staking.getDelegatorsToNodeCount(node.id)).to.be.eql(0n);
        expect(await staking.getDelegatorsToNode(node.id)).to.be.eql([]);

        // does not allow to collect fees after deletion
        await expect(staking.connect(node.wallet).requestAllFees(node.id)).to.be.revertedWithCustomError(nodes, "NodeDoesNotExist");

        // does not allow to send fees after deletion
        await expect(staking.connect(node.wallet).requestSendAllFees(node.wallet)).to.be.revertedWithCustomError(nodes, "AddressIsNotAssignedToAnyNode");

        // Fees should be locked for the node owner
        expect(await staking.connect(node.wallet).getMyTotalInExitQueue()).to.be.eql(fees);

        // Fees should be claimable after delay, even after node deletion
        // Deletion created a exit request, in this case with id 0
        await skipTime(ONE_DAY_IN_SECONDS);
        await expect(staking.connect(node.wallet).claimRequest(0)).to.changeEtherBalance(node.wallet, fees);
    });

    it("should apply validator fee on rewards", async () => {
        const {staking, status, nodesData } = await whitelistedNodes();
        const [owner,user] = await ethers.getSigners();
        const amount = ethers.parseEther("1");
        const reward = ethers.parseEther("2");
        const feeRate = 500; // Yes, Eddie, half
        const {id: node, wallet: nodeWallet} = nodesData[22]; // not in the current committee

        await staking.connect(nodeWallet).setFeeRate(feeRate);
        await staking.connect(user).stake(node, {value: amount});
        await sendHeartbeat(status, [nodesData[22]]); // Enable the node
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.getEarnedFeeAmount(node))
            .should.be.equal(reward / 2n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(amount + reward / 2n);


        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(1n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([user.address]);

        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount + reward);

        await staking.connect(user).requestRetrieve(node, amount);
        expect(await staking.connect(user).getStakedToNodeAmount(node)).to.be.eql(reward / 2n)
        expect(await staking.getNodeTotalStake(node)).to.be.eql(reward);
        await staking.connect(user).requestRetrieve(node, reward / 2n);
        expect(await staking.connect(user).getStakedToNodeAmount(node)).to.be.eql(0n)

        expect(await staking.getNodeTotalStake(node)).to.be.eql(reward / 2n);
        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(0n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([]);

        await staking.connect(nodeWallet).requestAllFees(node);

        (await staking.getEarnedFeeAmount(node))
            .should.be.equal(0n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(0n);

        expect(await staking.getDelegatorsToNodeCount(node)).to.be.eql(0n);
        expect(await staking.getDelegatorsToNode(node)).to.be.eql([]);
    });

    it("should apply validator fee on rewards when there are multiple nodes", async () => {
        const {staking, status, nodesData } = await whitelistedNodes();
        const [owner,user] = await ethers.getSigners();
        const amount1 = ethers.parseEther("2");
        const amount2 = ethers.parseEther("3");
        const reward = ethers.parseEther("10");
        const feeRate = 500; // Yes, Eddie, half
        const [{id: node1, wallet: node1Wallet}, {id: node2, wallet: node2Wallet}] = nodesData.slice(22); // not in the current committee

        await staking.connect(node1Wallet).setFeeRate(feeRate);
        await staking.connect(node2Wallet).setFeeRate(0);
        // root pool:
        //     total: 0 Fair, 0 credits
        //     node 1 pool:  0 Fair, 0 credits
        //     node 2 pool:  0 Fair, 0 credits
        // node 1 pool:
        //     total:   0 Fair, 0 node 1 credits
        //     node 1:  0 Fair, 0 node 1 credits
        // node 2 pool:
        //     total:   0 Fair, 0 node 2 credits
        //     node 2:  0 Fair, 0 node 2 credits
        await staking.connect(user).stake(node1, {value: amount1});
        // root pool:
        //     total: 2 Fair, 2 credits
        //     node 1 pool:  2 Fair, 2 credits
        //     node 2 pool:  0 Fair, 0 credits
        // node 1 pool:
        //     total:   2 Fair, 2 node 1 credits
        //     node 1:  0 Fair, 0 node 1 credits
        //     user:    2 Fair, 2 node 1 credits
        // node 2 pool:
        //     total:   0 Fair, 0 node 2 credits
        //     node 2:  0 Fair, 0 node 2 credits
        await staking.connect(user).stake(node2, {value: amount2});

        // Enable all nodes
        await sendHeartbeat(status, nodesData.slice(22));

        // root pool:
        //     total: 5 Fair, 5 credits
        //     node 1 pool:  2 Fair, 2 credits
        //     node 2 pool:  3 Fair, 3 credits
        // node 1 pool:
        //     total:   2 Fair, 2 node 1 credits
        //     node 1:  0 Fair, 0 node 1 credits
        //     user:    2 Fair, 2 node 1 credits
        // node 2 pool:
        //     total:   3 Fair, 3 node 2 credits
        //     node 2:  0 Fair, 0 node 2 credits
        //     user:    3 Fair, 3 node 1 credits
        await owner.sendTransaction({to: staking, value: reward});
        // root pool:
        //     total: 15 Fair, 5 credits
        //     node 1 pool:  6 Fair, 2 credits
        //     node 2 pool:  9 Fair, 3 credits
        // node 1 pool:
        //     total:   6 Fair, 3 node 1 credits
        //     node 1:  2 Fair, 1 node 1 credits
        //     user:    4 Fair, 2 node 1 credits
        // node 2 pool:
        //     total:   6 Fair, 3 node 2 credits
        //     node 2:  0 Fair, 0 node 2 credits
        //     user:    6 Fair, 3 node 1 credits

        const node1Reward = reward * amount1 / (amount1 + amount2);
        const node2Reward = reward * amount2 / (amount1 + amount2);
        const node1Fee = node1Reward / 2n;
        const stakedToNode1 = amount1 + node1Reward / 2n;
        (await staking.getEarnedFeeAmount(node1))
            .should.be.equal(node1Fee);
        (await staking.getStakedToNodeAmountFor(node1, user))
            .should.be.equal(stakedToNode1);
        (await staking.getStakedToNodeAmountFor(node2, user))
            .should.be.equal(amount2 + node2Reward);

        await staking.connect(node1Wallet).requestAllFees(node1);
        expect(await staking.connect(node1Wallet).getMyTotalInExitQueue()).to.be.eql(node1Fee);
        // root pool:
        //     total: 13 Fair, 4.(3) credits
        //     node 1 pool:  4 Fair, 1.(3) credits
        //     node 2 pool:  9 Fair, 3 credits
        // node 1 pool:
        //     total:   4 Fair, 2 node 1 credits
        //     node 1:  0 Fair, 0 node 1 credits
        //     user:    4 Fair, 2 node 1 credits
        // node 2 pool:
        //     total:   6 Fair, 3 node 2 credits
        //     node 2:  0 Fair, 0 node 2 credits
        //     user:    6 Fair, 3 node 1 credits

        (await staking.getEarnedFeeAmount(node1))
            .should.be.equal(0n);

        const amount = await staking.getStakedToNodeAmountFor(node1, user);
        expect(amount).to.be.closeTo(stakedToNode1, ALLOWED_ERROR);
        (await staking.getStakedAmountFor(user))
            .should.be.closeTo(stakedToNode1 + amount2 + node2Reward, ALLOWED_ERROR);

        await staking.connect(user).requestRetrieve(node1, amount);
        expect(await staking.connect(user).getMyTotalInExitQueue()).to.be.eql(amount);

        // root pool:
        //     total: 9 Fair, 3 credits
        //     node 1 pool:  0 Fair, 0 credits
        //     node 2 pool:  9 Fair, 3 credits
        // node 1 pool:
        //     total:   0 Fair, 0 node 1 credits
        //     node 1:  0 Fair, 0 node 1 credits
        //     user:    0 Fair, 0 node 1 credits
        // node 2 pool:
        //     total:   6 Fair, 3 node 2 credits
        //     node 2:  0 Fair, 0 node 2 credits
        //     user:    6 Fair, 3 node 1 credits

        (await staking.getEarnedFeeAmount(node1))
            .should.be.equal(0n);
        (await staking.getStakedToNodeAmountFor(node1, user))
            .should.be.equal(0n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(amount2 + node2Reward + 1n);

        await staking.connect(user).requestRetrieveAll(node2);

        (await staking.getStakedAmountFor(user))
            .should.be.equal(0n);
    });

    it("should allow to retrieve from a node from committee", async () => {
        const {committee, staking} = await stakedNodes();
        const [, user] = await ethers.getSigners();
        const activeCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex());
        const amount = ethers.parseEther("1");
        const retrieveAmount = ethers.parseEther("0.5");
        await staking.setRetrievingDelay(0n); // immediately available

        // stake to a committee node
        const committeeNode = activeCommittee.nodes[0];
        await staking.connect(user).stake(committeeNode, {value: amount});

        // should allow retrieval from committee node
        await staking.connect(user).requestRetrieve(committeeNode, retrieveAmount);
        await staking.connect(user).claimRequest(0).should.changeEtherBalance(user, retrieveAmount);

        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount - retrieveAmount);
    });

    it("should not pay rewards to stakers of unhealthy nodes", async () => {
        const {staking, status, nodesData, accessManager } = await whitelistedNodes();
        const [owner, ...allUsers] = await ethers.getSigners();
        const amounts = [2, 3, 5].map(String).map(ethers.parseEther);
        const users = allUsers.slice(0, amounts.length);
        const targetNodes = nodesData.slice(0, amounts.length);
        const feeRate = 500; // Yes, Eddie, half
        const tolerance = 10n; // 10 wei tolerance for rounding errors

        // set fee
        for (const node of targetNodes) {
            await staking.connect(node.wallet).setFeeRate(feeRate);
        }

        // stake to nodes
        for (const [user, node, amount] of zip(users, targetNodes, amounts)) {
            assert(node);
            await staking.connect(user).stake(node.id, {value: amount});
            expect(await staking.getNodeTotalStake(node.id)).to.be.eql(amount);
        }

        await sendHeartbeat(status, targetNodes); // Enable all nodes

        // allow admin to disable nodes for testing
        const [admin,] = await ethers.getSigners();
        const response = await accessManager.grantRole(await accessManager.COMMITTEE_ROLE(), admin, 0n);
        await response.wait();

        const disabledNode = targetNodes.slice(-1)[0];
        const delegatorOfDisabledNode = users.slice(-1)[0];
        await staking.disable(disabledNode.id);

        // pay rewards
        const reward = sumBigInt(amounts.slice(0, 2)) * 2n;
        await owner.sendTransaction({to: staking, value: reward});

        // check distribution
        for (const [user, amount] of zip(users, amounts)) {
            assert(amount && user);
            const currentBalance = user === delegatorOfDisabledNode ? amount : amount + amount;
            (await staking.connect(user).getStakedAmount())
                .should.be.equal(currentBalance);
        }
        for (const [node, amount] of zip(targetNodes, amounts)) {
            assert(node);
            const currentFee = node === disabledNode ? 0 : amount;
            (await staking.getEarnedFeeAmount(node.id))
                .should.be.equal(currentFee);
            (await staking.connect(node.wallet).requestAllFees(node.id))
                .should.changeEtherBalance(node.wallet, currentFee);
        }

        // current stakes are 4, 6 and 5

        await staking.enable(disabledNode.id);

        for (const [user, amount] of zip(users, amounts)) {
            assert(amount && user);
            const currentBalance = user === delegatorOfDisabledNode ? amount : amount + amount;
            (await staking.connect(user).getStakedAmount())
                .should.be.approximately(currentBalance, tolerance);
        }

        // pay rewards
        const secondReward = ethers.parseEther(String(15 * 2));
        await owner.sendTransaction({to: staking, value: secondReward});

        // check distribution
        for (const [user, amount] of zip(users, amounts)) {
            assert(amount && user);
            const currentBalance = user === delegatorOfDisabledNode ? amount * 2n : amount * 4n;
            (await staking.connect(user).getStakedAmount())
                .should.be.approximately(currentBalance, tolerance);
        }
        for (const [node, amount] of zip(targetNodes, amounts)) {
            assert(node && amount);
            const currentFee = node === disabledNode ? amount : amount * 2n;
            (await staking.getEarnedFeeAmount(node.id))
                .should.be.approximately(currentFee, tolerance);
            (await staking.connect(node.wallet).requestAllFees(node.id))
                .should.changeEtherBalance(node.wallet, currentFee);
        }
    });

    it("should pay rewards via reward wallet", async () => {
        const tolerance = 1n; // tolerance in wei for rounding errors
        const {staking, nodesData } = await registeredOnlyNodes();
        const [, ...allUsers] = await ethers.getSigners();
        const amounts = [2, 3].map(String).map(ethers.parseEther);
        const users = allUsers.slice(0, amounts.length);
        const targetNodes = nodesData.slice(0, amounts.length);
        const feeRate = 500; // Yes, Eddie, half
        const rewardWallets = await Promise.all(
            (await Promise.all(
                targetNodes.map(node => staking.getRewardWallet(node.id))
            )).map(rewardWalletAddress => ethers.getContractAt("RewardWallet", rewardWalletAddress))
        );

        await staking.setRetrievingDelay(0n); // immediately available

        // set fee
        for (const node of targetNodes) {
            await staking.connect(node.wallet).setFeeRate(feeRate);
        }

        // stake to nodes
        for (const [user, node, amount] of zip(users, targetNodes, amounts)) {
            assert(node);
            await staking.connect(user).stake(node.id, {value: amount});
            expect(await staking.getNodeTotalStake(node.id)).to.be.eql(amount);
        }

        const reward = ethers.parseEther("2");
        await setBalance(await ethers.resolveAddress(rewardWallets[0]), reward);

        let updatedAmounts = [3, 3].map(String).map(ethers.parseEther);
        let nodeFees = [1, 0].map(String).map(ethers.parseEther);

        // check distribution
        for (const [user, amount] of zip(users, updatedAmounts)) {
            assert(amount && user);
            (await staking.connect(user).getStakedAmount())
                .should.be.equal(amount);
        }
        for (const [node, amount] of zip(targetNodes, nodeFees)) {
            assert(node && amount !== undefined);
            (await staking.getEarnedFeeAmount(node.id))
                .should.be.approximately(amount, tolerance);
        }

        await rewardWallets[0].flush();
        (await ethers.provider.getBalance(rewardWallets[0]))
            .should.be.equal(0n);

        // check distribution
        for (const [user, amount] of zip(users, updatedAmounts)) {
            assert(amount && user);
            (await staking.connect(user).getStakedAmount())
                .should.be.equal(amount);
        }
        for (const [node, amount] of zip(targetNodes, nodeFees)) {
            assert(node && amount !== undefined);
            (await staking.getEarnedFeeAmount(node.id))
                .should.be.approximately(amount, tolerance);
        }

        // Pay more rewards
        await setBalance(await ethers.resolveAddress(rewardWallets[0]), reward);

        updatedAmounts = [4, 3].map(String).map(ethers.parseEther);
        nodeFees = [2, 0].map(String).map(ethers.parseEther);

        // check distribution
        for (const [user, amount] of zip(users, updatedAmounts)) {
            assert(amount && user);
            (await staking.connect(user).getStakedAmount())
                .should.be.equal(amount);
        }
        for (const [node, amount] of zip(targetNodes, nodeFees)) {
            assert(node && amount !== undefined);
            (await staking.getEarnedFeeAmount(node.id))
                .should.be.approximately(amount, tolerance);
        }

        await staking.connect(users[0]).requestRetrieve(targetNodes[0].id, updatedAmounts[0]);
        (await ethers.provider.getBalance(rewardWallets[0]))
            .should.be.equal(0n);
        await staking.connect(users[0]).claimRequest(0).should.changeEtherBalance(users[0], updatedAmounts[0]);

        updatedAmounts = [0, 3].map(String).map(ethers.parseEther);

        // check distribution
        for (const [user, amount] of zip(users, updatedAmounts)) {
            assert(user && amount !== undefined);
            (await staking.connect(user).getStakedAmount())
                .should.be.equal(amount);
        }
        for (const [node, amount] of zip(targetNodes, nodeFees)) {
            assert(node && amount !== undefined);
            (await staking.getEarnedFeeAmount(node.id))
                .should.be.approximately(amount, tolerance);
        }
    });

    it("should enforce node stake limits", async () => {
        const {staking, status, nodesData} = await whitelistedNodes();
        const [admin, user] = await ethers.getSigners();
        const node = nodesData[0].id;

        // Set stake limit to 10 ETH
        const stakeLimit = ethers.parseEther("10");
        await staking.connect(admin).setStakeLimit(stakeLimit);

        // Verify limit is set
        expect(await staking.stakeLimit()).to.be.equal(stakeLimit);

        // Stake 9 ETH (should succeed)
        const initialStake = ethers.parseEther("9");
        await staking.connect(user).stake(node, {value: initialStake});
        await sendHeartbeat(status, [nodesData[0]]); // Enable the node
        expect(await staking.getNodeTotalStake(node)).to.be.equal(initialStake);

        // Pay 2 ETH rewards
        const reward = ethers.parseEther("2");
        await admin.sendTransaction({to: staking, value: reward});

        // Check that node total stake is now 11 ETH (9 + 2 reward)
        const expectedTotalAfterReward = initialStake + reward;
        expect(await staking.getNodeTotalStake(node)).to.be.equal(expectedTotalAfterReward);

        // Try to stake 1 more ETH (should fail because 11 + 1 = 12 > 10 limit)
        const additionalStake = ethers.parseEther("1");
        await staking.connect(user).stake(node, {value: additionalStake})
            .should.be.revertedWithCustomError(
                staking,
                "StakeLimitExceeded"
            ).withArgs(
                expectedTotalAfterReward,
                additionalStake,
                stakeLimit
            );

        // Verify total stake hasn't changed
        expect(await staking.getNodeTotalStake(node)).to.be.equal(expectedTotalAfterReward);

        // Remove the limit and try staking again (should succeed)
        await staking.connect(admin).setStakeLimit(0);
        expect(await staking.stakeLimit()).to.be.equal(0);

        // Now we can stake the additional amount
        await staking.connect(user).stake(node, {value: additionalStake});
        expect(await staking.getNodeTotalStake(node)).to.be.equal(expectedTotalAfterReward + additionalStake);
    });

    it("should enforce node stake limits on payReward, except for protocol rewards", async () => {
        const {staking, status, nodesData} = await whitelistedNodes();
        const [admin, user] = await ethers.getSigners();
        const node = nodesData[0].id;

        // Set stake limit to 10 ETH
        const stakeLimit = ethers.parseEther("10");
        await staking.connect(admin).setStakeLimit(stakeLimit);

        // Verify limit is set
        expect(await staking.stakeLimit()).to.be.equal(stakeLimit);

        // Stake 9 ETH (should succeed)
        const initialStake = ethers.parseEther("9");
        await staking.connect(user).stake(node, {value: initialStake});
        await sendHeartbeat(status, [nodesData[0]]); // Enable the node
        expect(await staking.getNodeTotalStake(node)).to.be.equal(initialStake);

        // Pay 2 ETH rewards
        const reward = ethers.parseEther("2");
        await admin.sendTransaction({to: staking, value: reward});

        // Check that node total stake is now 11 ETH (9 + 2 reward)
        const expectedTotalAfterReward = initialStake + reward;
        expect(await staking.getNodeTotalStake(node)).to.be.equal(expectedTotalAfterReward);

        // Try to stake 1 more ETH (should fail because 11 + 1 = 12 > 10 limit)
        const additionalStake = ethers.parseEther("1");
        await staking.connect(user).stake(node, {value: additionalStake})
            .should.be.revertedWithCustomError(
                staking,
                "StakeLimitExceeded"
            ).withArgs(
                expectedTotalAfterReward,
                additionalStake,
                stakeLimit
            );

        // Verify total stake hasn't changed
        expect(await staking.getNodeTotalStake(node)).to.be.equal(expectedTotalAfterReward);

        // Try to pay 1 more ETH Rewards directly to node (should fail because 11 + 1 = 12 > 10 limit)
        await staking.connect(user).payReward(node, {value: additionalStake})
            .should.be.revertedWithCustomError(
                staking,
                "StakeLimitExceeded"
            ).withArgs(
                expectedTotalAfterReward,
                additionalStake,
                stakeLimit
            );

        // Try to pay 1 more ETH Rewards directly to node rewards wallet
        // (should fail because 11 + 1 = 12 > 10 limit)
        const rewardWallet = await ethers.getContractAt("RewardWallet", await staking.getRewardWallet(node));
        await user.sendTransaction({to: rewardWallet, value: additionalStake})
            .should.be.revertedWithCustomError(
                rewardWallet,
                "ValueExceedsStakeLimit"
            );

        // Consensus can pay 1 more ETH Rewards directly to node rewards wallet
        await setBalance(await rewardWallet.getAddress(), additionalStake);
        await rewardWallet.flush(); // but it should manually flush
        expect(await staking.getNodeTotalStake(node)).to.be.eql(expectedTotalAfterReward + additionalStake)

    });

    it("should set default fee rate to 1000 during node creation", async () => {
        const {nodes, staking} = await registeredOnlyNodes();

        // Create a new node wallet
        const nodeWallet = ethers.Wallet.createRandom().connect(ethers.provider);
        const [owner] = await ethers.getSigners();
        await owner.sendTransaction({
            to: nodeWallet.address,
            value: ethers.parseEther("1")
        });

        // Get a proper public key using the helper function
        const publicKey = await import("./tools/signatures").then(mod => mod.getPublicKey(nodeWallet));

        // Register the node
        await nodes.connect(nodeWallet).registerNode(
            ethers.randomBytes(4),
            publicKey,
            8000
        );

        const nodeId = await nodes.getNodeId(nodeWallet.address);

        // Check that the fee rate is set to 1000 (100%)
        expect(await staking.getNodeFeeRate(nodeId)).to.be.equal(1000);
    });

    it("should not create rounding errors bigger than MAX_ALLOWED_ERROR under defined precision", async () => {
        const {staking, nodesData, status} = await whitelistedNodes();
        const [, hacker, user] = await ethers.getSigners();
        const node = nodesData[0].id;
        const sufficientlyHighAmount = (HUGE_AMOUNT_OF_FAIR - ethers.parseEther("1")) / 100000n;

        await setBalance(hacker.address, sufficientlyHighAmount * 10n);
        await setBalance(user.address,  sufficientlyHighAmount * 10n);

        // Hacker 1 deposits 1 WEI
        await staking.connect(hacker).stake(node, {value: 1n});

        // [ earned fee | hacker stake , user stake ]
        // [ 0 | 1wei , 0 ]

        // eligible and fee rate to 0
        await status.connect(nodesData[0].wallet).alive();
        await staking.connect(nodesData[0].wallet).setFeeRate(0);

        // Hacker inflates Staking balance
        expect(await staking.getNodeTotalStake(node)).to.be.eql(1n);
        expect(await staking.getNodeShare(node)).to.be.eql(PRECISION);
        await hacker.sendTransaction({to: staking, value: sufficientlyHighAmount});
        // [ 0 | ∞ + 1 , 0 ]
        expect(await staking.getNodeShare(node)).to.be.eql(PRECISION);
        expect(await staking.getNodeTotalStake(node)).to.be.eql(sufficientlyHighAmount + 1n);

        // user deposits almostHalfMax ETH
        await staking.connect(user).stake(node, {value: sufficientlyHighAmount});
        // [ 0 | ∞ + 1, ∞ ]

        expect(await staking.getStakedToNodeAmountFor(node, user)).to.be.closeTo(sufficientlyHighAmount, ALLOWED_ERROR);
        expect(await staking.getStakedToNodeAmountFor(node, hacker)).to.be.closeTo(sufficientlyHighAmount + 1n, ALLOWED_ERROR);

        expect(await staking.getNodeTotalStake(node)).to.be.equal(2n * sufficientlyHighAmount + 1n);

        await staking.connect(hacker).requestRetrieveAll(node);
        // [ 0 | 0, ∞ ]
        await staking.connect(user).requestRetrieveAll(node);
        // [ 0 | 0, 0 ]

        expect(await staking.getNodeTotalStake(node)).to.be.equal(0n);
        // With fees
        const feeRate = 500; // Yes, Eddie, half
        await staking.connect(nodesData[0].wallet).setFeeRate(feeRate);
        await staking.connect(hacker).stake(node, {value: 1n});
        // [ 0 | 1, 0 ]
        await staking.connect(user).stake(node, {value: 1n});
        // [ 0 | 1, 1 ]
        await hacker.sendTransaction({to: staking, value: 1n});
        // [ 0 | 1, 1 ] but total stake is 3 (because 1 wei of reward can't be splitted)
        expect(await staking.getNodeTotalStake(node)).to.be.equal(3n);

        // Half of 1n should be rounded to 0
        expect(await staking.getEarnedFeeAmount(node)).to.be.equal(0n);
        expect(await staking.getStakedToNodeAmountFor(node, user)).to.be.equal(1n);
        expect(await staking.getStakedToNodeAmountFor(node, hacker)).to.be.equal(1n);

        await hacker.sendTransaction({to: staking, value: 1n});
        // [ 1 | 1, 1 ] + 1

        // Half of 2n should be 1n, but in fact it is not because of how rewards are calculated.
        // Each user has 1 Credit. The reward credits will be 2/3... When calculating the amount of FAIR using Credits roundedDown, it will be 0.99999 which is 0.
        // Reward credits are, however, updated to 2/3 rounded down (With Credit precision).
        expect(await staking.getEarnedFeeAmount(node)).to.be.equal(1n);
        expect(await staking.getStakedToNodeAmountFor(node, user)).to.be.equal(1n);
        expect(await staking.getStakedToNodeAmountFor(node, hacker)).to.be.equal(1n);

        await hacker.sendTransaction({to: staking, value: 1n});
        // [ 1 | 2, 2 ]

        // now with earned feed slightly higher than 1, we have 1n rewards
        expect(await staking.getEarnedFeeAmount(node)).to.be.equal(1n);

        // Lets try with huge rewards
        const totalRewards = (sufficientlyHighAmount + 3n);
        await hacker.sendTransaction({to: staking, value: sufficientlyHighAmount});
        expect(await staking.getEarnedFeeAmount(node)).to.be.closeTo(totalRewards/2n, ALLOWED_ERROR);
        expect(await staking.getStakedToNodeAmountFor(node, user)).to.be.closeTo(1n + totalRewards/4n, ALLOWED_ERROR);
        expect(await staking.getStakedToNodeAmountFor(node, hacker)).to.be.closeTo(1n + totalRewards/4n, ALLOWED_ERROR);
    });

    it("should not allow rounding errors bigger than MAX_ALLOWED_ERROR if precision changes", async () => {
        const {staking, nodesData, status} = await whitelistedNodes();
        const [, hacker, user] = await ethers.getSigners();
        const node = nodesData[0].id;

        const sufficientlyHighAmount = (HUGE_AMOUNT_OF_FAIR - ethers.parseEther("1")) / 100000n;

        await setBalance(hacker.address, sufficientlyHighAmount * 10n);
        await setBalance(user.address,  sufficientlyHighAmount * 10n);

        // Hacker 1 deposits 1 WEI
        await staking.connect(hacker).stake(node, {value: 1n});

        // eligible and fee rate to 0
        await status.connect(nodesData[0].wallet).alive();
        await staking.connect(nodesData[0].wallet).setFeeRate(0);

        // Hacker reduces its credits, affecting the precision
        for (let index = 0; index < N_PRECISION_BITS; index++) {
            await hacker.sendTransaction({to: staking, value: 1n});
            await staking.connect(hacker).requestRetrieve(node, 1n);
        }

        // Precision should be low enough, exactly 1 Credits instead of 1 << 80
        expect(await staking.getNodeShare(node)).to.be.equal(1n);

        // Hacker inflates Staking balance
        await hacker.sendTransaction({to: staking, value: sufficientlyHighAmount});

        // User is protected from depositing and losing ALL funds
        await expect(staking.connect(user).stake(node, {value: sufficientlyHighAmount}))
        .to.be.revertedWithCustomError(staking, "RoundingErrorTooHigh").withArgs(sufficientlyHighAmount);
    });

    it("All calculations should not overflow with MAX_STAKED_FAIR", async () => {
        const {staking, nodesData, status} = await whitelistedNodes();
        const [admin, user] = await ethers.getSigners();
        const stakeLimit = HUGE_AMOUNT_OF_FAIR - 1n;
        // inflate user balance

        await setBalance(user.address, stakeLimit + ethers.parseEther("1"));
        const node = nodesData[0].id;

        // Stake MAX (should succeed)
        const initialStake = stakeLimit;
        await staking.connect(user).stake(node, {value: initialStake});

        // eligible and fee rate to 0
        await status.connect(nodesData[0].wallet).alive();
        await staking.connect(nodesData[0].wallet).setFeeRate(0);

        // No Math should not overflow
        expect(await staking.getNodeTotalStake(node)).to.be.equal(initialStake);
        expect(await staking.getStakedAmountFor(user)).to.be.equal(initialStake);
        expect(await staking.getStakedToNodeAmountFor(node, user)).to.be.equal(initialStake);
        expect(await staking.getNodeShare(node)).to.be.equal(initialStake * (PRECISION));
        expect(initialStake * (PRECISION)).to.be.lessThan((1n << 256n));

        await staking.connect(user).requestRetrieve(node, 1n);
        await admin.sendTransaction({to: staking, value: 1n});
        // share is removed on retrieve but not changed when rewards were payed
        expect(await staking.getNodeShare(node)).to.be.equal((initialStake - 1n) * (PRECISION));

        // No Math should fail, rewards are given in full to the user
        expect(await staking.getNodeTotalStake(node)).to.be.equal(initialStake);
        expect(await staking.getStakedAmountFor(user)).to.be.equal(initialStake);
        expect(await staking.getStakedToNodeAmountFor(node, user)).to.be.equal(initialStake);

        await staking.connect(user).requestRetrieveAll(node);
        expect(await staking.getStakedAmountFor(user)).to.be.equal(0n);

        expect(await staking.getTotalInExitQueueFor(user)).to.be.eql(initialStake + 1n);
        expect(await staking.getExitRequestsCountFor(user)).to.be.eql(2n);
    });

    it("should not create phantom stake on withdraw", async () => {
        const {staking, status, nodesData} = await whitelistedNodes();
        const [goodNode, badNode] = nodesData;

        await staking.stake(goodNode.id, {value: ethers.parseEther("1")});
        await staking.stake(badNode.id, {value: ethers.parseEther("1")});
        await sendHeartbeat(status, [goodNode, badNode]);

        await setBalance(
            await ethers.resolveAddress(staking),
            await ethers.provider.getBalance(staking) + 1n
        ); // Pay 1e-18 fair reward

        expect(await staking.getNodeTotalStake(goodNode.id)).to.be.equal(ethers.parseEther("1"));
        expect(await staking.getNodeTotalStake(badNode.id)).to.be.equal(ethers.parseEther("1"));

        await staking.requestRetrieve(badNode.id, ethers.parseEther("1"));


        expect(await staking.getNodeTotalStake(badNode.id)).to.be.equal(0n);
        expect(await staking.getNodeShare(badNode.id)).to.be.equal(0n);

        expect(await staking.getNodeTotalStake(goodNode.id)).to.be.equal(ethers.parseEther("1") + 1n);
    });

    it("should not create phantom stake on claimFees", async () => {
        const {staking, status, nodesData} = await whitelistedNodes();
        const [goodNode, badNode] = nodesData;

        await staking.stake(goodNode.id, {value: ethers.parseEther("1")});
        await staking.payReward(badNode.id, {value: ethers.parseEther("1")});
        await sendHeartbeat(status, [goodNode, badNode]);

        await setBalance(
            await ethers.resolveAddress(staking),
            await ethers.provider.getBalance(staking) + 1n
        ); // Pay 1e-18 fair reward

        expect(await staking.getNodeTotalStake(goodNode.id)).to.be.equal(ethers.parseEther("1"));
        expect(await staking.getNodeTotalStake(badNode.id)).to.be.equal(ethers.parseEther("1"));
        expect(await staking.getEarnedFeeAmount(badNode.id)).to.be.equal(ethers.parseEther("1"));

        await staking.connect(badNode.wallet).requestAllFees(badNode.id);

        expect(await staking.getNodeTotalStake(badNode.id)).to.be.equal(0n);
        expect(await staking.getNodeShare(badNode.id)).to.be.equal(0n);

        expect(await staking.getNodeTotalStake(goodNode.id)).to.be.equal(ethers.parseEther("1") + 1n);
    });

    it("should not create phantom stake after node disabling", async () => {
        const {staking, status, nodesData} = await whitelistedNodes();
        const [goodNode, badNode] = nodesData;

        await staking.stake(goodNode.id, {value: ethers.parseEther("1")});
        await staking.stake(badNode.id, {value: ethers.parseEther("1")});
        await sendHeartbeat(status, [goodNode, badNode]);

        await setBalance(
            await ethers.resolveAddress(staking),
            await ethers.provider.getBalance(staking) + 1n
        ); // Pay 1e-18 fair reward

        await staking.disable(badNode.id);

        (
            await staking.getNodeTotalStake(goodNode.id) +
            await staking.getNodeTotalStake(badNode.id)
        ).should.be.equal(
            await ethers.provider.getBalance(staking)
        )
    });

    it("Node owners can only retrieve their rewards even if feeRate is 0", async () => {
        const {staking, nodesData} = await whitelistedNodes();
        const [node] = nodesData;
        const value = ethers.parseEther("1");
        const halfValue = value / 2n;
        await staking.stake(node.id, {value: value});
        // [fee: 0 fair, staked: 1 fair]
        await staking.connect(node.wallet).setFeeRate(500n);

        await setBalance(await staking.getRewardWallet(node.id), value);
        // [fee: 0.5 fair, staked: 1.5 fair]

        expect(await staking.getEarnedFeeAmount(node.id)).to.be.eql(halfValue);
        expect(await staking.getStakedAmount()).to.be.eql(value + halfValue);

        await expect(staking.connect(node.wallet).requestFees(node.id, value * 2n)).to.revertedWithCustomError(staking, "NotEnoughFee");
        await staking.connect(node.wallet).setFeeRate(0n);
        // setting fee to 0 does not compromise old earned fees
        expect(await staking.getEarnedFeeAmount(node.id)).to.be.eql(halfValue);
        await expect(staking.connect(node.wallet).requestFees(node.id, value * 2n)).to.revertedWithCustomError(staking, "NotEnoughFee");
        // [fee: 0.5 fair, staked: 1.5 fair]
        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(value + value);
        await staking.connect(node.wallet).requestAllFees(node.id);
        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(value + halfValue);
        expect(await staking.getEarnedFeeAmount(node.id)).to.be.eql(0n);
    });

    it("should allow alive() to enable node after receiving rewards", async () => {
        const {nodesData, staking, status} = await whitelistedNodes();
        const [node] = nodesData;
        const rewardWallet = await staking.getRewardWallet(node.id);
        await setBalance(rewardWallet, ethers.parseEther("3"));
        await setBalance(await ethers.resolveAddress(staking), ethers.parseEther("2"));
        await status.connect(node.wallet).alive();
    });

    it("should correctly process delayed rewards when fee rate is 0", async () => {
        const {nodesData: [node], staking} = await registeredOnlyNodes();
        const amount = ethers.parseEther("1");
        await staking.connect(node.wallet).setFeeRate(0);

        (await staking.getStakedAmount())
            .should.be.equal(0n);
        (await staking.getNodeTotalStake(node.id))
            .should.be.equal(0n);
        (await staking.getEarnedFeeAmount(node.id))
            .should.be.equal(0n);

        // Pay reward to a node without stake
        await setBalance(await staking.getRewardWallet(node.id), amount);

        (await staking.getStakedAmount())
            .should.be.equal(0n);
        (await staking.getNodeTotalStake(node.id))
            .should.be.equal(amount);
        (await staking.getEarnedFeeAmount(node.id))
            .should.be.equal(0n);

        // Stake to the node with reward waiting
        await staking.stake(node.id, {value: amount});

        (await staking.getStakedAmount())
            .should.be.equal(amount + amount); // stake + delayed reward
        (await staking.getNodeTotalStake(node.id))
            .should.be.equal(amount + amount);
        (await staking.getEarnedFeeAmount(node.id))
            .should.be.equal(0n);
    });

    it("should correctly process delayed rewards when fee rate is greater than 0", async () => {
        const {nodesData: [node], staking} = await registeredOnlyNodes();
        const amount = ethers.parseEther("1");
        await staking.connect(node.wallet).setFeeRate(500); // 50%

        (await staking.getStakedAmount())
            .should.be.equal(0n);
        (await staking.getNodeTotalStake(node.id))
            .should.be.equal(0n);
        (await staking.getEarnedFeeAmount(node.id))
            .should.be.equal(0n);

        // Pay reward to a node without stake
        await setBalance(await staking.getRewardWallet(node.id), amount);

        (await staking.getStakedAmount())
            .should.be.equal(0n);
        (await staking.getNodeTotalStake(node.id))
            .should.be.equal(amount);
        (await staking.getEarnedFeeAmount(node.id))
            .should.be.equal(amount);

        await staking.stake(node.id, {value: amount});

        (await staking.getStakedAmount())
            .should.be.equal(amount);
        (await staking.getNodeTotalStake(node.id))
            .should.be.equal(amount + amount);
        (await staking.getEarnedFeeAmount(node.id))
            .should.be.equal(amount);
    });
});
