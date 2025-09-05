// scripts/list-error-selectors.ts

// Import necessary components from Hardhat
import { artifacts, ethers } from "hardhat";
import { Artifact } from "hardhat/types";
import { contracts } from "./deploy";

/**
 * This script finds all custom error definitions in the ABI of specified contracts
 * and prints their names and 4-byte selectors (hashes).
 */
async function main(): Promise<void> {


  console.log("🔍 Finding custom error selectors...\n");

  for (const contractName of contracts) {
    try {
      // Read the contract artifact, which contains the ABI
      const artifact: Artifact = await artifacts.readArtifact(contractName);
      const abi = artifact.abi;

      // Filter the ABI to find only the entries of type "error"
      const errors = abi.filter((entry: any) => entry.type === "error");

      if (errors.length === 0) {
        console.log(`\n--- ${contractName} ---`);
        console.log("No custom errors found in this contract's ABI.");
        continue;
      }

      console.log(`\n--- ${contractName} ---`);

      for (const error of errors) {
        // Get the types of the error's inputs (parameters)
        const inputTypes: string[] = error.inputs.map((input: any) => input.type);

        // Construct the error signature string, e.g., "MyError(uint256,string)"
        const signature: string = `${error.name}(${inputTypes.join(',')})`;

        // Calculate the hash of the signature and take the first 4 bytes
        const selector: string = ethers.id(signature).substring(0, 10);

        console.log(`  Name: ${error.name}`);
        console.log(`  Selector: ${selector}`);
        console.log(`  Signature: ${signature}\n`);
      }

    } catch (error: any) {
      if (error.message.includes("is not a contract")) {
        console.error(`\nError: Could not find artifact for contract "${contractName}". Please check the name and make sure the contract is compiled.`);
      } else {
        console.error(`\nAn unexpected error occurred for contract "${contractName}":`, error);
      }
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: any) => {
    console.error(error);
    process.exit(1);
  });
