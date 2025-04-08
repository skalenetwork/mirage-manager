import { HardhatUserConfig } from "hardhat/config";
import '@nomicfoundation/hardhat-chai-matchers';
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-chai-matchers";
import '@openzeppelin/hardhat-upgrades';
import 'solidity-coverage'
import '@typechain/hardhat';

const config: HardhatUserConfig = {
  mocha: {
    timeout: 600000 // 10 minutes
  },
  solidity: "0.8.28",
};

export default config;
