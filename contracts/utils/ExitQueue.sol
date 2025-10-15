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

import { MAX_ITERATIONS } from "./constants.sol";
import { FundLibrary } from "./Fund.sol";

/**
 * @title Exit Queue Library
 * @author SKALE Labs
 * @notice Manages delayed retrieval of staked tokens
 */
library ExitQueueLibrary{
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Stores exit request data for a specific user
    struct UserExitData {
        EnumerableSet.UintSet requestIds;
        Fair totalLeaving;
    }

    /// @dev Main exit queue storage structure
    /// @dev Includes all exit requests, user-specific data, configuration, and data tracking values
    struct ExitQueue {
        mapping(uint256 requestId => IStaking.ExitRequest request) exitRequests;
        mapping(address user => UserExitData exitData) userExitData;
        Timestamp retrievingDelay;
        Fair totalInExitQueue; // total amount in exit queue
        uint256 numRequests; // total requests ever created (serves as unique id)
    }

    /**
     * @notice Emitted when a new exit request is created
     * @param user The address of the user creating the request
     * @param requestId The unique identifier of the request
     * @param nodeId The node identifier associated with the request
     * @param amount The amount of tokens in the request
     * @param unlockDate The timestamp when the request can be claimed
     */

    event RequestCreated(
        address indexed user,
        uint256 indexed requestId,
        NodeId indexed nodeId,
        Fair amount,
        Timestamp unlockDate
    );

    /**
     * @notice Emitted when an exit request is claimed
     * @param user The address of the user claiming the request
     * @param requestId The unique identifier of the request
     * @param nodeId The node identifier associated with the request
     * @param amount The amount of tokens claimed
     * @param claimDate The timestamp when the request was claimed
     */
    event RequestClaimed(
        address indexed user,
        uint256 indexed requestId,
        NodeId indexed nodeId,
        Fair amount,
        Timestamp claimDate
    );

    /// @dev The request with the given ID does not exist
    error RequestDoesNotExist(uint256 requestId);

    /// @dev The request does not exist for the specified user
    error RequestDoesNotExistForUser(address user, uint256 requestId);

    /// @dev The request is still locked and cannot be claimed yet
    error RequestIsStillLocked(Timestamp currentTime, Timestamp releaseTime);

    /// @dev The user does not have a request at the specified index
    error UserDoesNotHaveRequestAt(address user, uint256 index);

    /// @dev No unlocked requests found between start and end indexes
    error ZeroUnlockedRequests(address user, uint256 startIndex, uint256 endIndex);

    // internal

    /**
     * @dev Creates a new exit request for a user
     * @param queue The exit queue storage
     * @param user The address of the user
     * @param nodeId The node identifier
     * @param amount The amount of tokens to exit
     */
    function createRequest(
        ExitQueue storage queue,
        address user,
        NodeId nodeId,
        Fair amount
    )
        internal
    {
        if (amount == FundLibrary.ZERO_FAIR) {
            return;
        }
        Timestamp unlockDate = Timestamp.wrap(block.timestamp) + queue.retrievingDelay;
        UserExitData storage userData = queue.userExitData[user];
        uint256 requestId = queue.numRequests;
        assert(userData.requestIds.add(requestId));
        assert(queue.exitRequests[requestId].user == address(0));
        queue.exitRequests[requestId] = IStaking.ExitRequest({
            requestId: requestId,
            user: user,
            nodeId: nodeId,
            amount: amount,
            unlockDate: unlockDate
        });
        emit RequestCreated({
            user: user,
            requestId: requestId,
            nodeId: nodeId,
            amount: amount,
            unlockDate: unlockDate
        });
        ++queue.numRequests;
        userData.totalLeaving = userData.totalLeaving + amount;
        queue.totalInExitQueue = queue.totalInExitQueue + amount;
    }

    /**
     * @dev Claims an exit request for a user
     * @param queue The exit queue storage
     * @param user The address of the user claiming the request
     * @param id The unique identifier of the request
     * @return amount The amount of tokens claimed
     */
    function claim(ExitQueue storage queue, address user, uint256 id) internal returns (Fair amount) {
        IStaking.ExitRequest storage request = getRequest(queue, id);

        require(request.user == user, RequestDoesNotExistForUser(user, id));
        require(
            _isRequestUnlocked(request),
            RequestIsStillLocked(Timestamp.wrap(block.timestamp), request.unlockDate)
        );

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
     * @dev Checks if a request is unlocked
     * @param queue The exit queue storage
     * @param id The unique identifier of the request
     * @return isUnlocked True if the request is unlocked
     */
    function isRequestUnlocked(ExitQueue storage queue, uint256 id) internal view returns (bool isUnlocked) {
        return _isRequestUnlocked(getRequest(queue, id));
    }

    /**
     * @dev Returns the number of exit requests for a user
     * @param queue The exit queue storage
     * @param user The address of the user
     * @return numRequests The number of requests
     */
    function getNumRequestsForUser(ExitQueue storage queue, address user) internal view returns (uint256 numRequests) {
        return queue.userExitData[user].requestIds.length();
    }

    /**
     * @dev Retrieves an exit request by its ID
     * @param queue The exit queue storage
     * @param id The unique identifier of the request
     * @return request The exit request
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
     * @dev Retrieves an exit request for a user at a specific index
     * @param queue The exit queue storage
     * @param user The address of the user
     * @param index The index of the request in the user's request list
     * @return request The exit request
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
     * @dev Looks for an unlocked request in the first MAX_ITERATIONS requests starting after 'from'
     * @param queue The exit queue storage
     * @param user The address of the user
     * @param from The starting index to search from
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
            if(_isRequestUnlocked(req)){
                return req;
            }
        }
        revert ZeroUnlockedRequests(user, from, end);
    }

    /**
     * @dev Returns the total amount in the exit queue for a user
     * @param queue The exit queue storage
     * @param user The address of the user
     * @return amount The total amount in the queue
     */
    function getTotalInQueueForUser(ExitQueue storage queue, address user) internal view returns (Fair amount) {
        return queue.userExitData[user].totalLeaving;
    }

    // private

    /**
     * @dev Checks if a request is unlocked based on its unlock date
     * @param request The exit request to check
     * @return isUnlocked True if the request is unlocked
     */
    function _isRequestUnlocked(IStaking.ExitRequest storage request) private view returns (bool isUnlocked){
        return request.unlockDate < Timestamp.wrap(block.timestamp);
    }
}
