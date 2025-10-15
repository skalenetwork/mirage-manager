# Solidity API

## G2Operations

Provides functionality for working with G2 curve points

### doubleG2

```solidity
function doubleG2(struct IDkg.G2Point value) internal view returns (struct IDkg.G2Point result)
```

_Doubles a G2 point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.G2Point | The G2 point to double |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | struct IDkg.G2Point | The doubled G2 point |

### addG2

```solidity
function addG2(struct IDkg.G2Point value1, struct IDkg.G2Point value2) internal view returns (struct IDkg.G2Point sum)
```

_Adds two G2 points_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value1 | struct IDkg.G2Point | The first G2 point |
| value2 | struct IDkg.G2Point | The second G2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| sum | struct IDkg.G2Point | The sum of the two G2 points |

### getTWISTB

```solidity
function getTWISTB() internal pure returns (struct IDkg.Fp2Point point)
```

_Returns the TWIST B constant for G2 curve operations_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| point | struct IDkg.Fp2Point | The TWIST B constant as an Fp2 point |

### getG2Generator

```solidity
function getG2Generator() internal pure returns (struct IDkg.G2Point point)
```

_Returns the G2 generator point_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| point | struct IDkg.G2Point | The G2 generator point |

### getG2Zero

```solidity
function getG2Zero() internal pure returns (struct IDkg.G2Point point)
```

_Returns the G2 zero point (point at infinity)_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| point | struct IDkg.G2Point | The G2 zero point |

### isG2Point

```solidity
function isG2Point(struct IDkg.Fp2Point x, struct IDkg.Fp2Point y) internal pure returns (bool result)
```

_Checks if the given Fp2 coordinates represent a valid G2 point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | struct IDkg.Fp2Point | The x-coordinate as an Fp2 point |
| y | struct IDkg.Fp2Point | The y-coordinate as an Fp2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the coordinates form a valid G2 point, false otherwise |

### isG2

```solidity
function isG2(struct IDkg.G2Point value) internal pure returns (bool result)
```

_Checks if the given G2Point is a valid G2 point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.G2Point | The G2 point to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the point is on the G2 curve, false otherwise |

### isG2ZeroPoint

```solidity
function isG2ZeroPoint(struct IDkg.Fp2Point x, struct IDkg.Fp2Point y) internal pure returns (bool result)
```

_Checks if the given Fp2 coordinates represent the G2 zero point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | struct IDkg.Fp2Point | The x-coordinate as an Fp2 point |
| y | struct IDkg.Fp2Point | The y-coordinate as an Fp2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the coordinates form the G2 zero point, false otherwise |

### isG2Zero

```solidity
function isG2Zero(struct IDkg.G2Point value) internal pure returns (bool result)
```

_Checks if the given G2 point is the zero point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | struct IDkg.G2Point | The G2 point to check |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the point is the G2 zero point, false otherwise |

### isEqual

```solidity
function isEqual(struct IDkg.G2Point value1, struct IDkg.G2Point value2) internal pure returns (bool result)
```

_Checks if two G2 points are equal_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value1 | struct IDkg.G2Point | The first G2 point |
| value2 | struct IDkg.G2Point | The second G2 point |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | bool | True if the points are strictly equal, false otherwise |

