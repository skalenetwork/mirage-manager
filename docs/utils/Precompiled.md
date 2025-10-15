# Solidity API

## Precompiled

**dev:** _Library for interacting with Ethereum precompiled contracts and SKALE-specific precompiles
Provides utilities for modular exponentiation, elliptic curve operations (BN256),
and random number generation using SKALE's on-chain RNG._

### MOD_EXP

Address of the modular exponentiation precompiled contract

```solidity
address MOD_EXP
```

### EC_MUL

Address of the elliptic curve multiplication precompiled contract (BN256)

```solidity
address EC_MUL
```

### EC_PAIRING

Address of the elliptic curve pairing precompiled contract (BN256)

```solidity
address EC_PAIRING
```

### PrecompiledCallFailed

```solidity
error PrecompiledCallFailed(address precompiledContract)
```

**dev:** _Precompiled contract call failed_

### bigModExp

```solidity
function bigModExp(uint256 base, uint256 exponent, uint256 modulus) internal view returns (uint256 value)
```

**dev:** _Performs modular exponentiation: (base^exponent) % modulus_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| base | uint256 | The base value |
| exponent | uint256 | The exponent value |
| modulus | uint256 | The modulus value |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The result of (base^exponent) % modulus |

### bn256ScalarMul

```solidity
function bn256ScalarMul(uint256 x, uint256 y, uint256 k) internal view returns (uint256 xValue, uint256 yValue)
```

**dev:** _Performs elliptic curve scalar multiplication on BN256 curve_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | The x-coordinate of the point |
| y | uint256 | The y-coordinate of the point |
| k | uint256 | The scalar multiplier |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| xValue | uint256 | The x-coordinate of the resulting point |
| yValue | uint256 | The y-coordinate of the resulting point |

### bn256Pairing

```solidity
function bn256Pairing(uint256 x1, uint256 y1, uint256 a1, uint256 b1, uint256 c1, uint256 d1, uint256 x2, uint256 y2, uint256 a2, uint256 b2, uint256 c2, uint256 d2) internal view returns (bool pairing)
```

**dev:** _Performs BN256 elliptic curve pairing check
Verifies if e(p1[0], p2[0]) * e(p1[1], p2[1]) == 1_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x1 | uint256 | G1 point 1 x-coordinate |
| y1 | uint256 | G1 point 1 y-coordinate |
| a1 | uint256 | G2 point 1 first component x-coordinate |
| b1 | uint256 | G2 point 1 first component y-coordinate |
| c1 | uint256 | G2 point 1 second component x-coordinate |
| d1 | uint256 | G2 point 1 second component y-coordinate |
| x2 | uint256 | G1 point 2 x-coordinate |
| y2 | uint256 | G1 point 2 y-coordinate |
| a2 | uint256 | G2 point 2 first component x-coordinate |
| b2 | uint256 | G2 point 2 first component y-coordinate |
| c2 | uint256 | G2 point 2 second component x-coordinate |
| d2 | uint256 | G2 point 2 second component y-coordinate |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| pairing | bool | True if the pairing check passes |

### getRandomBytes32

```solidity
function getRandomBytes32(address rngOnChain) internal view returns (bytes32 addr)
```

**dev:** _Gets a random bytes32 value from SKALE's on-chain RNG
rngOnChain should be SKALE Random Number Generator predeployed or compatible contract_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rngOnChain | address | The address of the SKALE Random Number Generator predeployed contract |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| addr | bytes32 | The random bytes32 value |

### getRandomNumber

```solidity
function getRandomNumber(address rngOnChain) internal view returns (uint256 addr)
```

**dev:** _Gets a random uint256 value from SKALE's on-chain RNG_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rngOnChain | address | The address of the SKALE Random Number Generator predeployed contract |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| addr | uint256 | The random uint256 value |

