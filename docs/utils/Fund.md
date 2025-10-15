# Solidity API

## Credit

## Holder

## FundLibrary

Manages fund balances, credits, and fee collection for SKALE FAIR network participants

**dev:** _Implements a credit system for tracking proportional ownership in funds with fee management_

### Fund

**dev:** _Stores fund state including balances, credits, and fee tracking_

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

Precision multiplier for credit calculations

```solidity
uint256 CREDIT_PRECISION
```

### FEE_RATE_PRECISION

Precision value for fee rate calculations

```solidity
uint16 FEE_RATE_PRECISION
```

### NULL

Null holder identifier constant

```solidity
Holder NULL
```

### ZERO_FAIR

Zero FAIR token amount constant

```solidity
Fair ZERO_FAIR
```

### ZERO_CREDIT

Zero credit amount constant

```solidity
Credit ZERO_CREDIT
```

### NotEnoughStaked

```solidity
error NotEnoughStaked(Fair staked)
```

**dev:** _Indicates insufficient staked balance for a holder_

### NotEnoughFee

```solidity
error NotEnoughFee(Fair earnedFee)
```

**dev:** _Indicates insufficient earned fees for the node owner_

### RoundingErrorTooHigh

```solidity
error RoundingErrorTooHigh(Fair roundingError)
```

**dev:** _Indicates a rounding error exceeds the allowed threshold_

### claimFee

```solidity
function claimFee(struct FundLibrary.Fund fund, Fair fundBalance, Fair amount) internal
```

**dev:** _Claims accumulated fees from the fund - Relevant only for Node Funds_

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

**dev:** _Removes a specified amount from a holder's balance_

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

**dev:** _Sets the fee rate for the fund_

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

**dev:** _Adds funds to a holder's balance_

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

**dev:** _Updates the total balance of the fund and processes any balance changes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |

### getBalance

```solidity
function getBalance(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder) internal view returns (Fair amount)
```

**dev:** _Retrieves the balance for a specific holder_

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

**dev:** _Calculates total earned fees including uncounted fees_

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

**dev:** _Converts a Holder to an address_

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

**dev:** _Converts a Holder to a NodeId_

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

**dev:** _Converts an address to a Holder_

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

**dev:** _Converts a NodeId to a Holder_

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

