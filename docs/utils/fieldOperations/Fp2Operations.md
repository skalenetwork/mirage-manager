# Solidity API

## Fp2Operations

Provides functionality for working with Field P2 points

### P

BN254 base field prime modulus (alt_bn128). All arithmetic is modulo this value.

```solidity
uint256 P
```

### inverseFp2

```solidity
function inverseFp2(struct IDkg.Fp2Point value) internal view returns (struct IDkg.Fp2Point result)
```

**dev:** _Computes the inverse of an Fp2 point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.Fp2Point | The Fp2 point to invert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | struct IDkg.Fp2Point | The inverse of the input point |

### addFp2

```solidity
function addFp2(struct IDkg.Fp2Point value1, struct IDkg.Fp2Point value2) internal pure returns (struct IDkg.Fp2Point result)
```

**dev:** _Adds two Fp2 points_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value1 | struct IDkg.Fp2Point | The first Fp2 point |
| value2 | struct IDkg.Fp2Point | The second Fp2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | struct IDkg.Fp2Point | The sum of the two points |

### scalarMulFp2

```solidity
function scalarMulFp2(struct IDkg.Fp2Point value, uint256 scalar) internal pure returns (struct IDkg.Fp2Point result)
```

**dev:** _Multiplies an Fp2 point by a scalar value_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.Fp2Point | The Fp2 point to multiply |
| scalar | uint256 | The scalar value to multiply by |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | struct IDkg.Fp2Point | The product of the point and scalar |

### minusFp2

```solidity
function minusFp2(struct IDkg.Fp2Point diminished, struct IDkg.Fp2Point subtracted) internal pure returns (struct IDkg.Fp2Point difference)
```

**dev:** _Subtracts one Fp2 point from another_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| diminished | struct IDkg.Fp2Point | The point to subtract from (minuend) |
| subtracted | struct IDkg.Fp2Point | The point to subtract (subtrahend) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| difference | struct IDkg.Fp2Point | The difference between the two points |

### mulFp2

```solidity
function mulFp2(struct IDkg.Fp2Point value1, struct IDkg.Fp2Point value2) internal pure returns (struct IDkg.Fp2Point result)
```

**dev:** _Multiplies two Fp2 points_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value1 | struct IDkg.Fp2Point | The first Fp2 point |
| value2 | struct IDkg.Fp2Point | The second Fp2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | struct IDkg.Fp2Point | The product of the two points |

### squaredFp2

```solidity
function squaredFp2(struct IDkg.Fp2Point value) internal pure returns (struct IDkg.Fp2Point result)
```

**dev:** _Computes the square of an Fp2 point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.Fp2Point | The Fp2 point to square |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | struct IDkg.Fp2Point | The squared point |

### isEqual

```solidity
function isEqual(struct IDkg.Fp2Point value1, struct IDkg.Fp2Point value2) internal pure returns (bool result)
```

**dev:** _Checks if two Fp2 points are equal_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value1 | struct IDkg.Fp2Point | The first Fp2 point |
| value2 | struct IDkg.Fp2Point | The second Fp2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the points are equal, false otherwise |

