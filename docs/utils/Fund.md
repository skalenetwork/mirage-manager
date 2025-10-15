# Solidity API

## Credit

## Holder

## FundLibrary

Manages fund balances, credits, and fee collection for SKALE FAIR network participants

_Implements a credit system for tracking proportional ownership in funds with fee management_

### Fund

_Stores fund state including balances, credits, and fee tracking_

```solidity
struct Fund {
  Fair lastBalance;
  Credit totalCredits;
  struct TypedMap.HolderToCreditMap credits;
  Fair earnedFee;
  uint16 feeRate;
}
```

### CREDIT_PRECISION

```solidity
uint256 CREDIT_PRECISION
```

Precision multiplier for credit calculations

### FEE_RATE_PRECISION

```solidity
uint16 FEE_RATE_PRECISION
```

Precision value for fee rate calculations

### NULL

```solidity
Holder NULL
```

Null holder identifier constant

### ZERO_FAIR

```solidity
Fair ZERO_FAIR
```

Zero FAIR token amount constant

### ZERO_CREDIT

```solidity
Credit ZERO_CREDIT
```

Zero credit amount constant

### NotEnoughStaked

```solidity
error NotEnoughStaked(Fair staked)
```

_Indicates insufficient staked balance for a holder_

### NotEnoughFee

```solidity
error NotEnoughFee(Fair earnedFee)
```

_Indicates insufficient earned fees for the node owner_

### RoundingErrorTooHigh

```solidity
error RoundingErrorTooHigh(Fair roundingError)
```

_Indicates a rounding error exceeds the allowed threshold_

### claimFee

```solidity
function claimFee(struct FundLibrary.Fund fund, Fair fundBalance, Fair amount) internal
```

_Claims accumulated fees from the fund - Relevant only for Node Funds_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| amount | Fair | Amount of fees to claim |

### remove

```solidity
function remove(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder, Fair amount) internal
```

_Removes a specified amount from a holder's balance_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| holder | Holder | The holder to remove funds from |
| amount | Fair | Amount to remove |

### setFeeRate

```solidity
function setFeeRate(struct FundLibrary.Fund fund, Fair fundBalance, uint16 feeRate) internal
```

_Sets the fee rate for the fund_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| feeRate | uint16 | New fee rate to set |

### supply

```solidity
function supply(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder, Fair amount) internal
```

_Adds funds to a holder's balance_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| holder | Holder | The holder to add funds to |
| amount | Fair | Amount to supply |

### updateTotalBalance

```solidity
function updateTotalBalance(struct FundLibrary.Fund fund, Fair fundBalance) internal
```

_Updates the total balance of the fund and processes any balance changes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |

### getBalance

```solidity
function getBalance(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder) internal view returns (Fair amount)
```

_Retrieves the balance for a specific holder_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| holder | Holder | The holder to query |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | The holder's balance |

### getEarnedFee

```solidity
function getEarnedFee(struct FundLibrary.Fund fund, Fair balance) internal view returns (Fair amount)
```

_Calculates total earned fees including uncounted fees_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| balance | Fair | Current balance to calculate against |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | Fair | Total earned fees |

### holderToAddress

```solidity
function holderToAddress(Holder holder) internal pure returns (address holderAddress)
```

_Converts a Holder to an address_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | Holder | The holder identifier to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| holderAddress | address | The converted address |

### holderToNode

```solidity
function holderToNode(Holder holder) internal pure returns (NodeId node)
```

_Converts a Holder to a NodeId_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | Holder | The holder identifier to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The converted NodeId |

### addressToHolder

```solidity
function addressToHolder(address holder) internal pure returns (Holder typedHolder)
```

_Converts an address to a Holder_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | The address to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| typedHolder | Holder | The converted Holder identifier |

### nodeToHolder

```solidity
function nodeToHolder(NodeId holder) internal pure returns (Holder typedHolder)
```

_Converts a NodeId to a Holder_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | NodeId | The NodeId to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| typedHolder | Holder | The converted Holder identifier |

## _creditAdd

```solidity
function _creditAdd(Credit a, Credit b) internal pure returns (Credit sum)
```

## _creditEqual

```solidity
function _creditEqual(Credit a, Credit b) internal pure returns (bool equal)
```

## _creditLess

```solidity
function _creditLess(Credit a, Credit b) internal pure returns (bool less)
```

## _creditSubtract

```solidity
function _creditSubtract(Credit a, Credit b) internal pure returns (Credit diff)
```

