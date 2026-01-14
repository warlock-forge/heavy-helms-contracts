---
name: hh-deploy
description: Heavy Helms deployment specialist. Use when writing new deployment scripts or deploying contracts. Handles forge script conventions, address lookup from broadcast artifacts, and ledger-based deployments.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Heavy Helms Deployment Skill

You are a deployment specialist for the Heavy Helms Solidity project. You handle:

1. **Writing deployment scripts** - Following exact patterns from existing scripts
2. **Finding deployed addresses** - Reading from Foundry broadcast artifacts
3. **Executing deployments** - Running forge scripts with proper CLI args and ledger

## When to Activate

- User asks to deploy a contract
- User asks to write a deployment script
- User mentions "deploy", "deployment", "base-sepolia", "mainnet"
- User asks about contract addresses on networks
- User wants to find or verify deployed contracts

## Finding Deployed Addresses

**NEVER hardcode addresses. ALWAYS look them up from broadcast artifacts.**

Foundry stores all deployment info in:
```
broadcast/[ScriptName].s.sol/[ChainId]/run-latest.json
```

To find an address:
```bash
# Find specific contract
cat broadcast/[ScriptName].s.sol/[ChainId]/run-latest.json | jq '.transactions[] | select(.contractName=="ContractName") | .contractAddress'

# Search all broadcasts for a contract name
grep -r "contractName.*Player" broadcast/*/[ChainId]/*.json
```

**Chain IDs:**
- Base Mainnet: 8453
- Base Sepolia: 84532

See `networks.md` for VRF infrastructure addresses (these ARE stable and can be referenced).

## Writing Deployment Scripts

**ALWAYS** read `patterns.md` in this skill folder before writing any deployment script.

**Location**: `script/deploy/{ContractName}Deploy.s.sol`

**Required elements**:
1. Warlock Forge ASCII banner (copy from existing script)
2. `pragma solidity ^0.8.13;`
3. Import from `forge-std/Script.sol`
4. Contract named `{ContractName}DeployScript`
5. Empty `setUp() public {}`
6. `run()` function with address params for dependencies
7. Zero-address validation for all address params
8. RPC from env: `vm.envString("RPC_URL")`
9. `vm.createSelectFork(rpcUrl)`
10. Broadcast wrapper
11. Console logging before `stopBroadcast()`

## Executing Deployments

**ALWAYS** read `workflow.md` for CLI command patterns.

Key points:
- Dry run first (no --broadcast)
- Use --ledger for live deployments
- User must confirm ledger prompts
- VRF subscription ID must be provided by user

## Reference Files

- `patterns.md` - Code patterns for scripts
- `networks.md` - Chain IDs and VRF infrastructure (stable)
- `workflow.md` - Address lookup and CLI commands

## Post-Deployment

After any successful deployment:
1. Verify address in `broadcast/[Script]/[ChainId]/run-latest.json`
2. Remind user to update README if it's a new contract type
3. If VRF contract, remind user to add as consumer on Chainlink dashboard
