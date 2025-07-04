import chai, { assert } from "chai";
import { registeredOnlyNodes, stakedNodes } from "./tools/fixtures";
import { ethers } from "hardhat";
import { zip } from "lodash";

chai.should();

const sumBigInt = (arr: bigint[]) => arr.reduce((acc, val) => acc + val, 0n);

describe("Staking", () => {
    it("should allow holder to stake", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [,user] = await ethers.getSigners();
        const amount = ethers.parseEther("1");
        const node = nodesData[0].id;
        await staking.connect(user).stake(node, {value: amount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount);
    });

    it("should distribute rewards proportionally to stake", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [owner, user1, user2] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const reward = ethers.parseEther("5");
        const node = nodesData[0].id;

        await staking.connect(user1).stake(node, {value: amount1});
        await staking.connect(user2).stake(node, {value: amount2});

        // Pay reward
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.connect(user1).getStakedAmount())
            .should.be.equal(amount1 + reward * amount1 / (amount1 + amount2));
        (await staking.connect(user2).getStakedAmount())
            .should.be.equal(amount2 + reward * amount2 / (amount1 + amount2));
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
    });

    it("should be possible to retrieve", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [,user] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("1");
        const node = nodesData[22].id; // not in the current committee

        await staking.connect(user).stake(node, {value: initialAmount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);
        await staking.connect(user).retrieve(node, amount)
            .should.changeEtherBalance(user, amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount - amount);
    });

    it("should apply validator fee on rewards", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [owner,user] = await ethers.getSigners();
        const amount = ethers.parseEther("1");
        const reward = ethers.parseEther("2");
        const feeRate = 500; // Yes, Eddie, half
        const {id: node, wallet: nodeWallet} = nodesData[22]; // not in the current committee

        await staking.connect(nodeWallet).setFeeRate(feeRate);
        await staking.connect(user).stake(node, {value: amount});
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.getEarnedFeeAmount(node))
            .should.be.equal(reward / 2n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(amount + reward / 2n);

        await staking.connect(nodeWallet).claimAllFee(nodeWallet)
            .should.changeEtherBalance(nodeWallet, reward / 2n);
        await staking.connect(user).retrieve(node, amount + reward / 2n)
            .should.changeEtherBalance(user, amount + reward / 2n);

        (await staking.getEarnedFeeAmount(node))
            .should.be.equal(0n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(0n);
    });

    it("should apply validator fee on rewards when there are multiple nodes", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [owner,user] = await ethers.getSigners();
        const amount1 = ethers.parseEther("2");
        const amount2 = ethers.parseEther("3");
        const reward = ethers.parseEther("10");
        const roundingError = 1n;
        const feeRate = 500; // Yes, Eddie, half
        const [{id: node1, wallet: node1Wallet}, {id: node2}] = nodesData.slice(22); // not in the current committee

        await staking.connect(node1Wallet).setFeeRate(feeRate);
        // root pool:
        //     total: 0 Mirage, 0 credits
        //     node 1 pool:  0 Mirage, 0 credits
        //     node 2 pool:  0 Mirage, 0 credits
        // node 1 pool:
        //     total:   0 Mirage, 0 node 1 credits
        //     node 1:  0 Mirage, 0 node 1 credits
        // node 2 pool:
        //     total:   0 Mirage, 0 node 2 credits
        //     node 2:  0 Mirage, 0 node 2 credits
        await staking.connect(user).stake(node1, {value: amount1});
        // root pool:
        //     total: 2 Mirage, 2 credits
        //     node 1 pool:  2 Mirage, 2 credits
        //     node 2 pool:  0 Mirage, 0 credits
        // node 1 pool:
        //     total:   2 Mirage, 2 node 1 credits
        //     node 1:  0 Mirage, 0 node 1 credits
        //     user:    2 Mirage, 2 node 1 credits
        // node 2 pool:
        //     total:   0 Mirage, 0 node 2 credits
        //     node 2:  0 Mirage, 0 node 2 credits
        await staking.connect(user).stake(node2, {value: amount2});
        // root pool:
        //     total: 5 Mirage, 5 credits
        //     node 1 pool:  2 Mirage, 2 credits
        //     node 2 pool:  3 Mirage, 3 credits
        // node 1 pool:
        //     total:   2 Mirage, 2 node 1 credits
        //     node 1:  0 Mirage, 0 node 1 credits
        //     user:    2 Mirage, 2 node 1 credits
        // node 2 pool:
        //     total:   3 Mirage, 3 node 2 credits
        //     node 2:  0 Mirage, 0 node 2 credits
        //     user:    3 Mirage, 3 node 1 credits
        await owner.sendTransaction({to: staking, value: reward});
        // root pool:
        //     total: 15 Mirage, 5 credits
        //     node 1 pool:  6 Mirage, 2 credits
        //     node 2 pool:  9 Mirage, 3 credits
        // node 1 pool:
        //     total:   6 Mirage, 3 node 1 credits
        //     node 1:  2 Mirage, 1 node 1 credits
        //     user:    4 Mirage, 2 node 1 credits
        // node 2 pool:
        //     total:   6 Mirage, 3 node 2 credits
        //     node 2:  0 Mirage, 0 node 2 credits
        //     user:    6 Mirage, 3 node 1 credits

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

        await staking.connect(node1Wallet).claimAllFee(node1Wallet)
            .should.changeEtherBalance(node1Wallet, node1Fee);
        // root pool:
        //     total: 13 Mirage, 4.(3) credits
        //     node 1 pool:  4 Mirage, 1.(3) credits
        //     node 2 pool:  9 Mirage, 3 credits
        // node 1 pool:
        //     total:   4 Mirage, 2 node 1 credits
        //     node 1:  0 Mirage, 0 node 1 credits
        //     user:    4 Mirage, 2 node 1 credits
        // node 2 pool:
        //     total:   6 Mirage, 3 node 2 credits
        //     node 2:  0 Mirage, 0 node 2 credits
        //     user:    6 Mirage, 3 node 1 credits

        (await staking.getEarnedFeeAmount(node1))
            .should.be.equal(0n);
        (await staking.getStakedToNodeAmountFor(node1, user))
            .should.be.equal(stakedToNode1 - roundingError);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(stakedToNode1 + amount2 + node2Reward - roundingError);

        await staking.connect(user).retrieve(node1, stakedToNode1 - roundingError)
            .should.changeEtherBalance(user, stakedToNode1 - roundingError);
        // root pool:
        //     total: 9 Mirage, 3 credits
        //     node 1 pool:  0 Mirage, 0 credits
        //     node 2 pool:  9 Mirage, 3 credits
        // node 1 pool:
        //     total:   0 Mirage, 0 node 1 credits
        //     node 1:  0 Mirage, 0 node 1 credits
        //     user:    0 Mirage, 0 node 1 credits
        // node 2 pool:
        //     total:   6 Mirage, 3 node 2 credits
        //     node 2:  0 Mirage, 0 node 2 credits
        //     user:    6 Mirage, 3 node 1 credits

        (await staking.getEarnedFeeAmount(node1))
            .should.be.equal(0n);
        (await staking.getStakedToNodeAmountFor(node1, user))
            .should.be.equal(0n);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(amount2 + node2Reward + roundingError);
    });

    it("should not allow to retrieve from a node from committee", async () => {
        const {committee, staking} = await stakedNodes();
        const activeCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex());
        for (const node of activeCommittee.nodes) {
            await staking.retrieve(node, 1)
                .should.be.revertedWithCustomError(
                    staking,
                    "NodeInCommittee"
                ).withArgs(node);
        }
    });

    it("should not pay rewards to stakers of unhealthy nodes", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
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
        }

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
            (await staking.connect(node.wallet).claimAllFee(node.wallet))
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
            (await staking.connect(node.wallet).claimAllFee(node.wallet))
                .should.changeEtherBalance(node.wallet, currentFee);
        }
    });
});
