# @skalenetwork/fair-manager-types

TypeScript typings for SKALE Fair Manager smart contracts, generated with TypeChain.

## Installation

```bash
npm install @skalenetwork/fair-manager-types
# or
yarn add @skalenetwork/fair-manager-types
```

## Usage

This package provides TypeScript typings for three popular Ethereum libraries:

### Ethers v5

```typescript
import { Committee__factory } from '@skalenetwork/fair-manager-types/ethers-v5';
import { ethers } from 'ethers';

const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const committee = Committee__factory.connect(contractAddress, provider);
```

### Ethers v6

```typescript
import { Committee__factory } from '@skalenetwork/fair-manager-types/ethers-v6';
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('http://localhost:8545');
const committee = Committee__factory.connect(contractAddress, provider);
```

### Viem

```typescript
import { committeeAbi } from '@skalenetwork/fair-manager-types/viem';
import { createPublicClient, http } from 'viem';

const client = createPublicClient({
  transport: http('http://localhost:8545')
});

const data = await client.readContract({
  address: contractAddress,
  abi: committeeAbi,
  functionName: 'getCommitteeSize'
});
```

### ABI Files

You can also import raw ABI JSON files:

```typescript
import committeeAbi from '@skalenetwork/fair-manager-types/abi/Committee.json';
```

## Available Contracts

This package includes typings for all Fair Manager contracts:

- Committee
- DKG
- FairAccessManager
- Nodes
- RewardWallet
- Staking
- Status

And all related structs and interfaces.

## Peer Dependencies

**All peer dependencies are optional** - you only need to install what you're actually using:

- **Using ethers v5?** → `npm install ethers@^5.0.0`
- **Using ethers v6?** → `npm install ethers@^6.0.0`
- **Using viem?** → `npm install viem@^2.0.0`
- **Just need raw ABIs?** → No peer dependencies needed!

You can mix and match - install multiple if you need them, or just one.

## License

AGPL-3.0

## Links

- [GitHub Repository](https://github.com/skalenetwork/fair-manager)
- [SKALE Network](https://skale.space)
