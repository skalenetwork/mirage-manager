# Solidity API

## ExitQueueLibrary

Manages delayed retrieval of staked tokens

### UserExitData

**dev:** _Stores exit request data for a specific user_

```solidity
struct UserExitData {
  struct EnumerableSet.UintSet requestIds;
  Fair totalLeaving;
}
```

### ExitQueue

**dev:** _Main exit queue storage structure
Includes all exit requests, user-specific data, configuration, and data tracking values_

```solidity
struct ExitQueue {
  mapping(uint256 => struct IStaking.ExitRequest) exitRequests;
  mapping(address => struct ExitQueueLibrary.UserExitData) userExitData;
  Timestamp retrievingDelay;
  Fair totalInExitQueue;
  uint256 numRequests;
}
```

### RequestCreated

Emitted when a new exit request is created

```solidity
event RequestCreated(address user, uint256 requestId, NodeId nodeId, Fair amount, Timestamp unlockDate)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The address of the user creating the request |
| requestId | uint256 | The unique identifier of the request |
| nodeId | NodeId | The node identifier associated with the request |
| amount | Fair | The amount of tokens in the request |
| unlockDate | Timestamp | The timestamp when the request can be claimed |

### RequestClaimed

Emitted when an exit request is claimed

```solidity
event RequestClaimed(address user, uint256 requestId, NodeId nodeId, Fair amount, Timestamp claimDate)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user | address | The address of the user claiming the request |
| requestId | uint256 | The unique identifier of the request |
| nodeId | NodeId | The node identifier associated with the request |
| amount | Fair | The amount of tokens claimed |
| claimDate | Timestamp | The timestamp when the request was claimed |

### RequestDoesNotExist

```solidity
error RequestDoesNotExist(uint256 requestId)
```

**dev:** _The request with the given ID does not exist_

### RequestDoesNotExistForUser

```solidity
error RequestDoesNotExistForUser(address user, uint256 requestId)
```

**dev:** _The request does not exist for the specified user_

### RequestIsStillLocked

```solidity
error RequestIsStillLocked(Timestamp currentTime, Timestamp releaseTime)
```

**dev:** _The request is still locked and cannot be claimed yet_

### UserDoesNotHaveRequestAt

```solidity
error UserDoesNotHaveRequestAt(address user, uint256 index)
```

**dev:** _The user does not have a request at the specified index_

### ZeroUnlockedRequests

```solidity
error ZeroUnlockedRequests(address user, uint256 startIndex, uint256 endIndex)
```

**dev:** _No unlocked requests found between start and end indexes_

### createRequest

```solidity
function createRequest(struct ExitQueueLibrary.ExitQueue queue, address user, NodeId nodeId, Fair amount) internal
```

**dev:** _Creates a new exit request for a user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| user | address | The address of the user |
| nodeId | NodeId | The node identifier |
| amount | Fair | The amount of tokens to exit |

### claim

```solidity
function claim(struct ExitQueueLibrary.ExitQueue queue, address user, uint256 id) internal returns (Fair amount)
```

**dev:** _Claims an exit request for a user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| user | address | The address of the user claiming the request |
| id | uint256 | The unique identifier of the request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The amount of tokens claimed |

### isRequestUnlocked

```solidity
function isRequestUnlocked(struct ExitQueueLibrary.ExitQueue queue, uint256 id) internal view returns (bool isUnlocked)
```

**dev:** _Checks if a request is unlocked_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| id | uint256 | The unique identifier of the request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| isUnlocked | bool | True if the request is unlocked |

### getNumRequestsForUser

```solidity
function getNumRequestsForUser(struct ExitQueueLibrary.ExitQueue queue, address user) internal view returns (uint256 numRequests)
```

**dev:** _Returns the number of exit requests for a user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| user | address | The address of the user |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| numRequests | uint256 | The number of requests |

### getRequest

```solidity
function getRequest(struct ExitQueueLibrary.ExitQueue queue, uint256 id) internal view returns (struct IStaking.ExitRequest request)
```

**dev:** _Retrieves an exit request by its ID_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| id | uint256 | The unique identifier of the request |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The exit request |

### getRequestAt

```solidity
function getRequestAt(struct ExitQueueLibrary.ExitQueue queue, address user, uint256 index) internal view returns (struct IStaking.ExitRequest request)
```

**dev:** _Retrieves an exit request for a user at a specific index_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| user | address | The address of the user |
| index | uint256 | The index of the request in the user's request list |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The exit request |

### getUnlockedRequest

```solidity
function getUnlockedRequest(struct ExitQueueLibrary.ExitQueue queue, address user, uint256 from) internal view returns (struct IStaking.ExitRequest request)
```

**dev:** _Looks up for an unlocked request in the first MAX_ITERATIONS requests starting after 'from'_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| user | address | The address of the user |
| from | uint256 | The starting index to search from |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| request | struct IStaking.ExitRequest | The first unlocked exit request found |

### getTotalInQueueForUser

```solidity
function getTotalInQueueForUser(struct ExitQueueLibrary.ExitQueue queue, address user) internal view returns (Fair amount)
```

**dev:** _Returns the total amount in the exit queue for a user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| queue | struct ExitQueueLibrary.ExitQueue | The exit queue storage |
| user | address | The address of the user |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The total amount in the queue |

