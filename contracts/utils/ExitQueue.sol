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

    uint256 public constant MAX_ITERATIONS = 2000;

    event RequestCreated(
        address indexed user, uint256 indexed requestId, NodeId indexed nodeId, Fair amount, Timestamp unlockDate
    );

    event RequestClaimed(
        address indexed user, uint256 indexed requestId, NodeId indexed nodeId, Fair amount, Timestamp claimDate
    );

    error RequestDoesNotExist(uint256 requestId);
    error RequestDoesNotExistForUser(address user, uint256 requestId);
    error RequestIsStillLocked(Timestamp currentTime, Timestamp releaseTime);
    error UserDoesNotHaveRequestAt(address user, uint256 index);
    error ZeroUnlockedRequests(address user, uint256 startIndex, uint256 endIndex);

    // internal

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

    function isRequestUnlocked(ExitQueue storage queue, uint256 id) internal view returns (bool isUnlocked) {
        return _isRequestUnlocked(getRequest(queue, id));
    }

    function getNumRequestsForUser(ExitQueue storage queue, address user) internal view returns (uint256 numRequests) {
        return queue.userExitData[user].requestIds.length();
    }

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

    //@dev Looks up for an unlocked request in the first MAX_ITERATIONS requests starting after 'from'
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

    function getTotalInQueueForUser(ExitQueue storage queue, address user) internal view returns (Fair amount) {
        return queue.userExitData[user].totalLeaving;
    }

    // private

    function _isRequestUnlocked(IStaking.ExitRequest storage request) private view returns (bool isUnlocked) {
        return request.unlockDate < Timestamp.wrap(block.timestamp);
    }

}
