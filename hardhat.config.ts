import { HardhatUserConfig } from "hardhat/config";
import '@nomicfoundation/hardhat-chai-matchers';
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-chai-matchers";
import '@openzeppelin/hardhat-upgrades';
import 'solidity-coverage'
import '@typechain/hardhat';
import 'hardhat-dependency-compiler';
import * as dotenv from "dotenv"

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    custom: {
      url: process.env.ENDPOINT || "http://localhost:8545",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    }
  },
  dependencyCompiler: {
    paths: [
      '@skalenetwork/skale-manager-interfaces/INodes.sol',
      '@skalenetwork/skale-manager-interfaces/ISchainsInternal.sol',
      '@skalenetwork/skale-manager-interfaces/IKeyStorage.sol'
    ]
  }
};

export default config;
