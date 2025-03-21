import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-network-helpers";
import '@openzeppelin/hardhat-upgrades';
import 'solidity-coverage'
import '@typechain/hardhat';

const config: HardhatUserConfig = {
  solidity: "0.8.28",
};

export default config;
