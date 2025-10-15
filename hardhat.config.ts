import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@openzeppelin/hardhat-upgrades";
import "solidity-coverage"
import "@typechain/hardhat";
import "hardhat-dependency-compiler";
import "@nomicfoundation/hardhat-verify";
import "solidity-docgen";
import * as dotenv from "dotenv";

// Cspell:words sourcify

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      }
    }
  },
  networks: {
    custom: {
      url: process.env.ENDPOINT || "http://localhost:8545",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    }
  },
  etherscan: {
    apiKey: {
      custom: "custom"
    },
    customChains: [
      {
        network: "custom",
        chainId: Number(process.env.CHAIN_ID),
        urls: {
          apiURL: `${process.env.EXPLORER_URL}/api`,
          browserURL: `${process.env.EXPLORER_URL}`
        }
      }
    ]
  },
  sourcify: {
    enabled: false
  },
  dependencyCompiler: {
    paths: [
      "@skalenetwork/skale-manager-interfaces/INodes.sol",
      "@skalenetwork/skale-manager-interfaces/ISchainsInternal.sol",
      "@skalenetwork/skale-manager-interfaces/IKeyStorage.sol"
    ],
    keep: true
  },
  docgen: {
    outputDir: "docs",
    pages: "files",
    templates: "./docs/templates",
    exclude: [
      "hardhat-dependency-compiler",
      "test",
      "utils/constants.sol",
      "utils/errors.sol"
    ]
  }
};

export default config;
