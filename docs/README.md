# Documentation Generation

This project uses [solidity-docgen](https://github.com/OpenZeppelin/solidity-docgen) to automatically generate documentation from NatSpec comments in the Solidity smart contracts.

## Generating Documentation

To generate the documentation, run:

```bash
yarn docgen
```

This will:
1. Compile the smart contracts
2. Extract NatSpec comments from the code
3. Generate Markdown files in the `docs/` directory

## CI/CD Validation

The documentation is **validated by CI/CD** in the test pipeline:
- After linting, the pipeline runs `yarn docgen`
- Checks if generated docs match committed docs
- **Fails if documentation is out of date**

This ensures documentation always stays in sync with the code.

### If CI Fails

If the "Check documentation is up to date" step fails:

```bash
# Regenerate documentation
yarn docgen

# Commit the changes
git add docs/
git commit -m "docs: regenerate documentation"
git push
```

## Documentation Structure

The generated documentation includes:

- **Contract Overview**: High-level description with @notice and @dev comments
- **State Variables**: Constants and storage variables with their descriptions
- **Events**: All events emitted by contracts with their parameters
- **Errors**: Custom error definitions
- **Functions**: Public and external functions with:
  - Function signatures
  - Parameters and their descriptions (@param)
  - Return values (@return)
  - NatSpec comments (@notice, @dev)
- **Modifiers**: Access control and validation modifiers
- **Structs & Enums**: Data structures used by contracts

## Generated Files

Documentation is organized by contract:
- Main contracts: `Committee.md`, `DKG.md`, `Nodes.md`, `Staking.md`, etc.
- Structs and utility contracts in subdirectories
- All formatted as GitHub-flavored Markdown

## Configuration

Documentation generation is configured in `hardhat.config.ts`:

```typescript
docgen: {
  outputDir: "docs",
  pages: "files",  // One file per contract
  exclude: [
    "hardhat-dependency-compiler",
    "test",
    "utils/constants.sol",
    "utils/errors.sol"
  ]
}
```

## Customizing Templates

The documentation uses the default templates from solidity-docgen, which work perfectly for extracting NatSpec comments.

If you need custom formatting, you can:
1. Create a `docs/templates/` directory
2. Copy templates from the solidity-docgen package
3. Modify them as needed
4. Add `templates: "docs/templates"` to the hardhat.config.ts docgen configuration

## What Gets Excluded

The following are automatically excluded from documentation:
- Test contracts (in `test/` directory)
- Internal utilities (`utils/constants.sol`, `utils/errors.sol`)
- External dependencies (from `node_modules`)
- Hardhat dependency compiler artifacts

## Writing Good NatSpec

For best documentation results, use complete NatSpec comments:

```solidity
/**
 * @title ContractTitle
 * @author Author Name
 * @notice Brief description for end users
 * @dev Technical details for developers
 */
contract MyContract {
    /**
     * @notice Brief description of what the function does
     * @dev Technical implementation details
     * @param paramName Description of the parameter
     * @return returnName Description of what is returned
     */
    function exampleFunction(uint256 paramName)
        external
        returns (uint256 returnName)
    {
        // implementation
    }

    /**
     * @notice Description of what this event tracks
     * @param user The user involved in the event
     * @param amount The amount involved
     */
    event ExampleEvent(address indexed user, uint256 amount);
}
```

## Viewing Documentation

The generated Markdown files can be viewed:
- **On GitHub/GitLab**: They render automatically with nice formatting
- **In VS Code**: Use the Markdown preview (Ctrl+Shift+V)
