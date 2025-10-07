// SPDX-License-Identifier: AGPL-3.0-only

/*
    ExitQueue.sol - fair-manager
    Copyright (C) 2025-Present SKALE Labs
    @author Dmytro Stebaiev

    fair-manager is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fair-manager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with fair-manager.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { NodeId } from "@skalenetwork/fair-manager-interfaces/INodes.sol";
import { IStaking } from "@skalenetwork/fair-manager-interfaces/IStaking.sol";
import { Fair, Timestamp } from "@skalenetwork/fair-manager-interfaces/units.sol";
import { FundLibrary } from "./Fund.sol";

/**
 * @title ExitQueueLibrary
 * @notice Library for managing exit queues in a staking system
 * @dev Provides functions for creating, claiming, and managing exit requests for Staking contract.
 */
library ExitQueueLibrary {

    using EnumerableSet for EnumerableSet.UintSet;

    struct UserExitData {
        EnumerableSet.UintSet requestIds;
        Fair totalLeaving;
    }

    struct ExitQueue {
        mapping(uint256 requestId => IStaking.ExitRequest request) exitRequests;
        mapping(address user => UserExitData exitData) userExitData;
        Timestamp retrievingDelay;
        Fair totalInExitQueue; // total amount in exit queue
        uint256 numRequests; // total requests ever created (serves as unique id)
    }

    /// @notice Maximum number of iterations for searching unlocked requests
    uint256 public constant MAX_ITERATIONS = 2000;

    /**
     * @notice Emitted when a new exit request is created
     * @param user The address of the user creating the request
     * @param requestId The unique ID of the exit request
     * @param nodeId The ID of the node associated with the request
     * @param amount The amount of tokens to exit
     * @param unlockDate The timestamp when the request will be unlocked
     */
    event RequestCreated(
        address indexed user, uint256 indexed requestId, NodeId indexed nodeId, Fair amount, Timestamp unlockDate
    );

    /**
     * @notice Emitted when an exit request is claimed
     * @param user The address of the user claiming the request
     * @param requestId The unique ID of the exit request
     * @param nodeId The ID of the node associated with the request
     * @param amount The amount claimed
     * @param claimDate The block timestamp when the request was claimed
     */
    event RequestClaimed(
        address indexed user, uint256 indexed requestId, NodeId indexed nodeId, Fair amount, Timestamp claimDate
    );

    error RequestDoesNotExist(uint256 requestId);
    error RequestDoesNotExistForUser(address user, uint256 requestId);
    error RequestIsStillLocked(Timestamp currentTime, Timestamp releaseTime);
    error UserDoesNotHaveRequestAt(address user, uint256 index);
    error ZeroUnlockedRequests(address user, uint256 startIndex, uint256 endIndex);

    // internal

    /**
     * @notice Generates and registers a new exit request in the queue.
     * @param queue The exit queue to update
     * @param user The address of the user creating the request
     * @param nodeId The ID of the node associated with the request
     * @param amount The amount to exit
     */
    function createRequest(ExitQueue storage queue, address user, NodeId nodeId, Fair amount) internal {
        if (amount == FundLibrary.ZERO_FAIR) {
            return;
        }
        Timestamp unlockDate = Timestamp.wrap(block.timestamp) + queue.retrievingDelay;
        UserExitData storage userData = queue.userExitData[user];
        uint256 reqId = queue.numRequests;
        assert(userData.requestIds.add(reqId));
        assert(queue.exitRequests[reqId].user == address(0));
        queue.exitRequests[reqId] = IStaking.ExitRequest({
            requestId: reqId,
            user: user,
            nodeId: nodeId,
            amount: amount,
            unlockDate: unlockDate
        });
        emit RequestCreated({ user: user, requestId: reqId, nodeId: nodeId, amount: amount, unlockDate: unlockDate });
        ++queue.numRequests;
        userData.totalLeaving = userData.totalLeaving + amount;
        queue.totalInExitQueue = queue.totalInExitQueue + amount;
    }

    /**
     * @notice Claims an exit request
     * @dev Removes an existing unlocked exit request for a user from the queue.
     * @param queue The exit queue to update
     * @param user The address of the user claiming the request
     * @param id The ID of the exit request to claim
     * @return amount The amount claimed
     */
    function claim(ExitQueue storage queue, address user, uint256 id) internal returns (Fair amount) {
        IStaking.ExitRequest storage request = getRequest(queue, id);

        require(request.user == user, RequestDoesNotExistForUser(user, id));
        require(_isRequestUnlocked(request), RequestIsStillLocked(Timestamp.wrap(block.timestamp), request.unlockDate));

        amount = request.amount;
        UserExitData storage userData = queue.userExitData[user];
        assert(userData.requestIds.remove(id));
        userData.totalLeaving = userData.totalLeaving - amount;
        queue.totalInExitQueue = queue.totalInExitQueue - amount;
        emit RequestClaimed({
            user: user,
            requestId: id,
            nodeId: request.nodeId,
            amount: amount,
            claimDate: Timestamp.wrap(block.timestamp)
        });

        delete queue.exitRequests[id];
    }

    /**
     * @notice Checks if an exit request is unlocked
     * @dev Verifies if the unlock date of the request has passed.
     * @param queue The exit queue to query
     * @param id The ID of the exit request to check
     * @return isUnlocked True if the request is unlocked, false otherwise
     */
    function isRequestUnlocked(ExitQueue storage queue, uint256 id) internal view returns (bool isUnlocked) {
        return _isRequestUnlocked(getRequest(queue, id));
    }

    /**
     * @notice Retrieves the number of pending exit requests for a user
     * @param queue The exit queue to query
     * @param user The address of the user
     * @return numRequests The number of exit requests for the user
     */
    function getNumRequestsForUser(ExitQueue storage queue, address user) internal view returns (uint256 numRequests) {
        return queue.userExitData[user].requestIds.length();
    }

    /**
     * @notice Retrieves an exit request by ID
     * @param queue The exit queue to query
     * @param id The ID of the exit request
     * @return request The exit request associated with the ID
     */
    function getRequest(
        ExitQueue storage queue,
        uint256 id
    )
        internal
        view
        returns (IStaking.ExitRequest storage request)
    {
        request = queue.exitRequests[id];
        require(request.user != address(0), RequestDoesNotExist(id));
    }

    /**
     * @notice Retrieves an exit request at a specific index for a user
     * @param queue The exit queue to query
     * @param user The address of the user
     * @param index The index of the exit request
     * @return request The exit request at the specified index
     */
    function getRequestAt(
        ExitQueue storage queue,
        address user,
        uint256 index
    )
        internal
        view
        returns (IStaking.ExitRequest memory request)
    {
        require(index < getNumRequestsForUser(queue, user), UserDoesNotHaveRequestAt(user, index));
        uint256 id = queue.userExitData[user].requestIds.at(index);
        return queue.exitRequests[id];
    }

    /**
     * @notice Retrieves the first unlocked exit request for a user
     * @dev Searches for an unlocked request starting from a specific index - up to MAX_ITERATIONS.
     * @param queue The exit queue to query
     * @param user The address of the user
     * @param from The starting index for the search
     * @return request The first unlocked exit request found
     */
    function getUnlockedRequest(
        ExitQueue storage queue,
        address user,
        uint256 from
    )
        internal
        view
        returns (IStaking.ExitRequest memory request)
    {
        uint256 numRequests = getNumRequestsForUser(queue, user);
        require(from < numRequests, UserDoesNotHaveRequestAt(user, from));
        uint256 end = Math.min(numRequests, from + MAX_ITERATIONS);
        UserExitData storage userData = queue.userExitData[user];
        for (uint256 i = from; i < end; ++i) {
            uint256 id = userData.requestIds.at(i);
            IStaking.ExitRequest storage req = queue.exitRequests[id];
            if (_isRequestUnlocked(req)) {
                return req;
            }
        }
        revert ZeroUnlockedRequests(user, from, end);
    }

    /**
     * @notice Retrieves the total amount in the exit queue for a user
     * @param queue The exit queue to query
     * @param user The address of the user
     * @return amount The total amount in the exit queue for the user
     */
    function getTotalInQueueForUser(ExitQueue storage queue, address user) internal view returns (Fair amount) {
        return queue.userExitData[user].totalLeaving;
    }

    // private

    /**
     * @notice Checks if an exit request is unlocked
     * @dev Verifies if the unlock date of the request has passed.
     * @param request The exit request to check
     * @return isUnlocked True if the request is unlocked, false otherwise
     */
    function _isRequestUnlocked(IStaking.ExitRequest storage request) private view returns (bool isUnlocked) {
        return request.unlockDate < Timestamp.wrap(block.timestamp);
    }

}
