# Solidity API

## G1Operations

Provides functionality for working with the elliptic-curve subgroup over Fp

### getG1Generator

Returns the G1 generator point

```solidity
function getG1Generator() internal pure returns (struct IDkg.Fp2Point generator)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| generator | struct IDkg.Fp2Point | The G1 generator point |

### isG1Point

Checks if the given coordinates represent a valid G1 point

```solidity
function isG1Point(uint256 x, uint256 y) internal pure returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | The x-coordinate of the point |
| y | uint256 | The y-coordinate of the point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the point is on the G1 curve, false otherwise |

### isG1

Checks if the given Fp2Point is a valid G1 point

```solidity
function isG1(struct IDkg.Fp2Point point) internal pure returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| point | struct IDkg.Fp2Point | The Fp2 point to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the point is on the G1 curve, false otherwise |

### checkRange

Checks if a point's coordinates are within the valid range

```solidity
function checkRange(struct IDkg.Fp2Point point) internal pure returns (bool result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| point | struct IDkg.Fp2Point | The Fp2 point to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if both coordinates are less than the prime P, false otherwise |

### negate

Computes the negation of a y-coordinate in the field

```solidity
function negate(uint256 y) internal pure returns (uint256 result)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| y | uint256 | The y-coordinate to negate |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | uint256 | The negated y-coordinate |

