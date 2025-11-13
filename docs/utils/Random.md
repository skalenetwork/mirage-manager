# Solidity API

## Random

Library for generating pseudo-random numbers using seed-based generation

**dev:** _Provides utilities for creating random number generators and generating values
within specified ranges for weighted sampling and selection algorithms._

### create

Creates a RandomGenerator instance from a seed value

```solidity
function create(uint256 seed) internal pure returns (struct IRandom.RandomGenerator generator)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| seed | uint256 | The initial seed value for random generation |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| generator | struct IRandom.RandomGenerator | The initialized RandomGenerator |

### createFromEntropy

Creates a RandomGenerator instance from entropy bytes

```solidity
function createFromEntropy(bytes entropy) internal pure returns (struct IRandom.RandomGenerator generator)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| entropy | bytes | The entropy bytes to hash into a seed |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| generator | struct IRandom.RandomGenerator | The initialized RandomGenerator |

### random

Generates a random value and updates the generator state

```solidity
function random(struct IRandom.RandomGenerator self) internal pure returns (uint256 value)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| self | struct IRandom.RandomGenerator | The RandomGenerator instance (modified in place) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The generated random uint256 value |

### random

Generates a random value in the range [0, max)

```solidity
function random(struct IRandom.RandomGenerator self, uint256 max) internal pure returns (uint256 value)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| self | struct IRandom.RandomGenerator | The RandomGenerator instance (modified in place) |
| max | uint256 | The exclusive upper bound (must be greater than 0) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The generated random value in range [0, max) |

### random

Generates a random value in the range [min, max)

```solidity
function random(struct IRandom.RandomGenerator self, uint256 min, uint256 max) internal pure returns (uint256 value)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| self | struct IRandom.RandomGenerator | The RandomGenerator instance (modified in place) |
| min | uint256 | The inclusive lower bound |
| max | uint256 | The exclusive upper bound (must be greater than min) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The generated random value in range [min, max) |

