# Solidity API

## FairAccessManager

Manages role-based access control for the FAIR network contracts

_Extends OpenZeppelin's AccessManagerUpgradeable to define specific roles
for Committee, Nodes, Staking, and Status contracts. Each role controls access
to specific contract functions._

### COMMITTEE_ROLE

```solidity
uint64 COMMITTEE_ROLE
```

Role ID for Committee contract operations

### NODES_ROLE

```solidity
uint64 NODES_ROLE
```

Role ID for Nodes contract operations

### STAKING_ROLE

```solidity
uint64 STAKING_ROLE
```

Role ID for Staking contract operations

### STATUS_ROLE

```solidity
uint64 STATUS_ROLE
```

Role ID for Status contract operations

### initialize

```solidity
function initialize(address initialAdmin) public
```

Initializes the FairAccessManager contract

_Sets up the initial admin with full access control privileges_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initialAdmin | address | The address that will be granted admin role |

