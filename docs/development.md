# Heavy Helms Development Guide

## Important Notes

- **Via IR**: Enabled in foundry.toml for optimization
- **Solady**: Primary dependency for gas-optimized contracts
- **Testing**: Extensive test coverage expected, use `-vv` for debugging
- **Gas Optimization**: Critical due to on-chain game nature

## Performance Optimization

- Optimize contracts for gas efficiency, considering storage layout and function optimization
- Implement efficient indexing and querying strategies for off-chain data
- Pack related storage variables to optimize gas usage (same storage slot)
- Minimize on-chain storage and computation when possible
- Use events for data that doesn't need to be accessed on-chain
- Batch operations to save gas when possible
- Consider using bitmap/bitwise operations for storing boolean flags
- Cache storage variables in memory within functions to reduce sload operations
- Be conscious of SSTORE costs - especially when frequently updating the same variable
- Consider unifying related functions to save on contract size and reduce deployment costs

## Development Workflow Guidelines

- Utilize Foundry's forge for compilation, testing, and deployment
- Use Foundry's cast for command-line interaction with contracts
- Implement comprehensive Foundry scripts for deployment and verification
- Use Foundry's script capabilities for complex deployment sequences
- Implement a robust CI/CD pipeline for smart contract deployments
- Use static type checking and linting tools in pre-commit hooks
- Utilize `forge fmt` if prompted about consistent code formatting
- Use a well-defined versioning strategy for contract deployments
- Implement a formal code review process before deployment
- Maintain a deployment registry with contract addresses and ABIs
- Implement monitoring and alerting systems for production contracts

## Documentation Standards

- Document code thoroughly, focusing on why rather than what
- Maintain up-to-date API documentation for smart contracts
- Create and maintain comprehensive project documentation, including architecture diagrams and decision logs
- Document test scenarios and their purpose clearly
- Document any assumptions made in the contract design
- Create detailed diagrams of contract interactions for complex systems
- Include explicit permission models in documentation
- Document expected gas costs for key operations
- Include contingency plans for potential failure modes

## Dependencies Management

- Use Solady (vectorized/solady) as a primary source of gas-optimized dependencies
- Ensure that any libraries used are installed with forge, and remappings are set
- Place remappings in `foundry.toml` instead of a `remappings.txt` file
- Periodically audit and update dependencies to benefit from security patches
- Pin dependency versions to ensure deterministic builds

## Environment Configuration

### When via_ir is required:

```toml
# via_ir pipeline is very slow - use a separate profile to pre-compile and then use vm.getCode to deploy
[profile.via_ir]
via_ir = true
# do not compile tests when compiling via-ir
test = 'src'
out = 'via_ir-out'
```

### When deterministic deployment is required:

```toml
[profile.deterministic]
# ensure that block number + timestamp are realistic when running tests
block_number = 17722462
block_timestamp = 1689711647
# don't pollute bytecode with metadata
bytecode_hash = 'none'
cbor_metadata = false
```
