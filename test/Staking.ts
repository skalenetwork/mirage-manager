import chai, { assert, expect } from "chai";
import { registeredOnlyNodes, stakedNodes } from "./tools/fixtures";
import { ethers } from "hardhat";
import { zip } from "lodash";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";

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
        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount);

    });

    it("should distribute rewards proportionally to stake", async () => {
        const {staking, nodesData } = await registeredOnlyNodes();
        const [owner, user1, user2] = await ethers.getSigners();
        const [amount1, amount2] = [ethers.parseEther("2"), ethers.parseEther("3")];
        const reward = ethers.parseEther("5");
        const node = nodesData[0].id;

        // Set fee rate to 0 for proportional distribution
        await staking.connect(nodesData[0].wallet).setFeeRate(0);

        await staking.connect(user1).stake(node, {value: amount1});
        await staking.connect(user2).stake(node, {value: amount2});
        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount1 + amount2);
        // Pay reward
        await owner.sendTransaction({to: staking, value: reward});

        (await staking.connect(user1).getStakedAmount())
            .should.be.equal(amount1 + reward * amount1 / (amount1 + amount2));
        (await staking.connect(user2).getStakedAmount())
            .should.be.equal(amount2 + reward * amount2 / (amount1 + amount2));

        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount1 + amount2 + reward);
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
        expect(await staking.getNodeTotalStake(node)).to.be.eql(initialAmount);

        await staking.connect(user).retrieve(node, amount)
            .should.changeEtherBalance(user, amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount - amount);

        expect(await staking.getNodeTotalStake(node)).to.be.eql(initialAmount - amount);
    });

    it("should be possible to retrieve from deleted Node", async () => {
        const {staking, nodesData, nodes} = await registeredOnlyNodes();
        const [,user] = await ethers.getSigners();
        const initialAmount = ethers.parseEther("3");
        const amount = ethers.parseEther("1");
        const node = nodesData[22]; // not in the current committee

        await staking.connect(user).stake(node.id, {value: initialAmount});
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount);
        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(initialAmount);
        await nodes.connect(node.wallet).deleteNode(node.id);
        expect(await nodes.activeNodeExists(node.id)).to.be.eql(false);
        expect(await staking.isNodeEnabled(node.id)).to.be.eql(false);
        await staking.connect(user).retrieve(node.id, amount)
            .should.changeEtherBalance(user, amount);
        (await staking.connect(user).getStakedAmount())
            .should.be.equal(initialAmount - amount);

        expect(await staking.getNodeTotalStake(node.id)).to.be.eql(initialAmount - amount);
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

        await staking.connect(nodeWallet).claimAllFee(ethers.ZeroAddress)
            .should.be.revertedWithCustomError(staking, "ZeroAddress");

        await staking.connect(nodeWallet).claimAllFee(nodeWallet)
            .should.changeEtherBalance(nodeWallet, reward / 2n);

        expect(await staking.getNodeTotalStake(node)).to.be.eql(amount + reward / 2n);

        await staking.connect(user).retrieve(node, amount + reward / 2n)
            .should.changeEtherBalance(user, amount + reward / 2n);

        expect(await staking.getNodeTotalStake(node)).to.be.eql(0n);

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

        await staking.connect(node1Wallet).claimAllFee(node1Wallet)
            .should.changeEtherBalance(node1Wallet, node1Fee);
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
        (await staking.getStakedToNodeAmountFor(node1, user))
            .should.be.equal(stakedToNode1 - roundingError);
        (await staking.getStakedAmountFor(user))
            .should.be.equal(stakedToNode1 + amount2 + node2Reward - roundingError);

        await staking.connect(user).retrieve(node1, stakedToNode1 - roundingError)
            .should.changeEtherBalance(user, stakedToNode1 - roundingError);
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
            .should.be.equal(amount2 + node2Reward + roundingError);
    });

    it("should allow to retrieve from a node from committee", async () => {
        const {committee, staking} = await stakedNodes();
        const [, user] = await ethers.getSigners();
        const activeCommittee = await committee.getCommittee(await committee.getActiveCommitteeIndex());
        const amount = ethers.parseEther("1");
        const retrieveAmount = ethers.parseEther("0.5");

        // stake to a committee node
        const committeeNode = activeCommittee.nodes[0];
        await staking.connect(user).stake(committeeNode, {value: amount});

        // should allow retrieval from committee node
        await staking.connect(user).retrieve(committeeNode, retrieveAmount)
            .should.changeEtherBalance(user, retrieveAmount);

        (await staking.connect(user).getStakedAmount())
            .should.be.equal(amount - retrieveAmount);
    });

    it("should not pay rewards to stakers of unhealthy nodes", async () => {
        const {staking, nodesData, accessManager } = await registeredOnlyNodes();
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

        await staking.connect(users[0]).retrieve(targetNodes[0].id, updatedAmounts[0])
            .should.changeEtherBalance(users[0], updatedAmounts[0]);
        (await ethers.provider.getBalance(rewardWallets[0]))
            .should.be.equal(0n);

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
        const {staking, nodesData} = await registeredOnlyNodes();
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

});
