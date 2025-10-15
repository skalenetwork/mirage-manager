# Solidity API

## FairAccessManager

Manages role-based access control for the FAIR network contracts

**dev:** _Extends OpenZeppelin's AccessManagerUpgradeable to define specific roles
for Committee, Nodes, Staking, and Status contracts. Each role controls access
to specific contract functions._

### COMMITTEE_ROLE

Role ID for Committee contract operations

```solidity
uint64 COMMITTEE_ROLE
```

### NODES_ROLE

Role ID for Nodes contract operations

```solidity
uint64 NODES_ROLE
```

### STAKING_ROLE

Role ID for Staking contract operations

```solidity
uint64 STAKING_ROLE
```

### STATUS_ROLE

Role ID for Status contract operations

```solidity
uint64 STATUS_ROLE
```

### initialize

Initializes the FairAccessManager contract

```solidity
function initialize(address initialAdmin) public
```

**dev:** _Sets up the initial admin with full access control privileges_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAdmin | address | The address that will be granted admin role |

