import { HardhatUserConfig } from "hardhat/config";
import '@nomicfoundation/hardhat-chai-matchers';
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-chai-matchers";
import '@openzeppelin/hardhat-upgrades';
import 'solidity-coverage'
import '@typechain/hardhat';

const config: HardhatUserConfig = {
  networks: {
    custom: {
      url: process.env.ENDPOINT || "http://localhost:8545",
      accounts: process.env.PRIVATE_KEY? [process.env.PRIVATE_KEY] : []
    }
  },
  solidity: "0.8.28",
};

export default config;
