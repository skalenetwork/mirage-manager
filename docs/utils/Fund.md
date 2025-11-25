# Solidity API

## Credit

## Holder

## FundLibrary

Facilitates reward distribution and management operations in the FAIR network

**dev:** _Implements a credit system for tracking proportional ownership in funds with fee management_

### Fund

Struct representing fund state including balances, credits, and fee tracking

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

Claims accumulated fees from the fund

```solidity
function claimFee(struct FundLibrary.Fund fund, Fair fundBalance, Fair amount) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| amount | Fair | Amount of fees to claim |

### remove

Removes a specified amount from a holder's balance

```solidity
function remove(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder, Fair amount) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| holder | Holder | The holder to remove funds from |
| amount | Fair | Amount to remove |

### setFeeRate

Sets the fee rate for the fund

```solidity
function setFeeRate(struct FundLibrary.Fund fund, Fair fundBalance, uint16 feeRate) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| feeRate | uint16 | New fee rate to set |

### supply

Adds funds to a holder's balance

```solidity
function supply(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder, Fair amount) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |
| holder | Holder | The holder to add funds to |
| amount | Fair | Amount to supply |

### updateTotalBalance

Updates the total balance of the fund and processes any balance changes

```solidity
function updateTotalBalance(struct FundLibrary.Fund fund, Fair fundBalance) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| fund | struct FundLibrary.Fund | Storage reference to the fund |
| fundBalance | Fair | Current balance of the fund |

### getBalance

Retrieves the balance for a specific holder

```solidity
function getBalance(struct FundLibrary.Fund fund, Fair fundBalance, Holder holder) internal view returns (Fair amount)
```

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

Calculates total earned fees including uncounted fees

```solidity
function getEarnedFee(struct FundLibrary.Fund fund, Fair balance) internal view returns (Fair amount)
```

**dev:** _Earned fees are updated using a lazy approach based on balance changes.
The amount of fees earned should never be higher than the current balance._

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

Converts a Holder to an address

```solidity
function holderToAddress(Holder holder) internal pure returns (address holderAddress)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | Holder | The holder identifier to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| holderAddress | address | The converted address |

### holderToNode

Converts a Holder to a NodeId

```solidity
function holderToNode(Holder holder) internal pure returns (NodeId node)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | Holder | The holder identifier to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| node | NodeId | The converted NodeId |

### addressToHolder

Converts an address to a Holder

```solidity
function addressToHolder(address holder) internal pure returns (Holder typedHolder)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | address | The address to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| typedHolder | Holder | The converted Holder identifier |

### nodeToHolder

Converts a NodeId to a Holder

```solidity
function nodeToHolder(NodeId holder) internal pure returns (Holder typedHolder)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| holder | NodeId | The NodeId to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| typedHolder | Holder | The converted Holder identifier |

## _creditAdd

Adds two credit amounts

```solidity
function _creditAdd(Credit a, Credit b) internal pure returns (Credit sum)
```

### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| a | Credit | The first credit amount |
| b | Credit | The second credit amount |

### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| sum | Credit | The sum of the two credit amounts |

## _creditEqual

Checks if two credit amounts are equal

```solidity
function _creditEqual(Credit a, Credit b) internal pure returns (bool equal)
```

### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| a | Credit | The first credit amount |
| b | Credit | The second credit amount |

### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| equal | bool | True if the credit amounts are equal, false otherwise |

## _creditLess

Checks if one credit amount is less than another

```solidity
function _creditLess(Credit a, Credit b) internal pure returns (bool less)
```

### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| a | Credit | The first credit amount |
| b | Credit | The second credit amount |

### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| less | bool | True if a is less than b, false otherwise |

## _creditSubtract

Subtracts two credit amounts

```solidity
function _creditSubtract(Credit a, Credit b) internal pure returns (Credit diff)
```

### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| a | Credit | The first credit amount |
| b | Credit | The second credit amount |

### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| diff | Credit | The result of subtracting b from a |

