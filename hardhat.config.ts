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
import { parseEther, Wallet } from "ethers";
import { HardhatNetworkAccountUserConfig } from "hardhat/types";

dotenv.config();

export const DEPLOYER_PHRASE = "test test test test test test test test test test test junk";


function getAccounts() {
  const accounts: HardhatNetworkAccountUserConfig[] = [];
  const defaultBalance = parseEther("2000000").toString();

  // First account with known mnemonic
  accounts.push({
    privateKey: Wallet.fromPhrase(DEPLOYER_PHRASE).privateKey,
    balance: defaultBalance,
  })
  const n = 10;
  for (let i = 0; i < n; ++i) {
    accounts.push({
      privateKey: Wallet.createRandom().privateKey,
      balance: defaultBalance
    })
  }

  return accounts;
}

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hardhat:{
      accounts: getAccounts()
    },
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
    ],
    keep: true
  }
};

export default config;
