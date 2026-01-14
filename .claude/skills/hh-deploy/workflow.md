# Deployment Workflow

## Finding Deployed Addresses

**NEVER hardcode addresses. ALWAYS look them up.**

### From Broadcast Artifacts (Authoritative Source)

Foundry stores all deployment data in:
```
broadcast/[ScriptName].s.sol/[ChainId]/run-latest.json
```

**Find a specific contract address:**
```bash
# Using jq
cat broadcast/FighterDeploy.s.sol/84532/run-latest.json | jq '.transactions[] | select(.contractName=="Player") | .contractAddress'

# Using grep (quick search)
grep -o '"contractAddress":"0x[^"]*"' broadcast/FighterDeploy.s.sol/84532/run-latest.json
```

**Search all broadcasts for a contract:**
```bash
# Find Player contract on Base Sepolia
grep -r '"contractName":"Player"' broadcast/*/84532/*.json

# Find any contract by partial name
grep -r "contractName.*Game" broadcast/*/84532/*.json
```

**List all deployed contracts from a script:**
```bash
cat broadcast/FighterDeploy.s.sol/84532/run-latest.json | jq '.transactions[] | {name: .contractName, address: .contractAddress}'
```

### Common Deploy Scripts and What They Deploy

| Script | Contracts Deployed |
|--------|-------------------|
| `GameEngineDeploy.s.sol` | GameEngine |
| `FighterDeploy.s.sol` | Player, PlayerTickets, DefaultPlayer, Monster, PlayerDataCodec, DefaultPlayerSkinNFT, MonsterSkinNFT |
| `PracticeGameDeploy.s.sol` | PracticeGame |
| `GauntletGameDeploy.s.sol` | GauntletGame (3 instances for level brackets) |
| `DuelGameDeploy.s.sol` | DuelGame |
| `TournamentGameDeploy.s.sol` | TournamentGame |

## Writing a New Deploy Script

1. **Check constructor requirements**
   ```bash
   grep -A 20 "constructor(" src/path/to/Contract.sol
   ```

2. **Find dependency addresses** from broadcast artifacts (see above)

3. **Create script** at `script/deploy/{ContractName}Deploy.s.sol`
   - Follow patterns in `patterns.md` exactly

4. **Compile to verify**
   ```bash
   forge build
   ```

## Executing Deployments

### Step 1: Dry Run (Simulation)

Test without sending transactions:

```bash
# No params
forge script script/deploy/ContractDeploy.s.sol \
  --rpc-url $RPC_URL

# With params
forge script script/deploy/ContractDeploy.s.sol \
  --sig "run(address,address,uint256,bytes32)" \
  0xGameEngine 0xPlayer 12345 0xKeyHash \
  --rpc-url $RPC_URL
```

### Step 2: Live Deploy with Ledger

```bash
forge script script/deploy/ContractDeploy.s.sol \
  --sig "run(address,address)" \
  0xAddr1 0xAddr2 \
  --rpc-url $RPC_URL \
  --broadcast \
  --ledger \
  --sender <YOUR_LEDGER_ADDRESS>
```

**User action required**: Confirm transaction(s) on Ledger device.

### Step 3: Verify on Block Explorer (Optional)

```bash
forge script script/deploy/ContractDeploy.s.sol \
  --sig "run(address,address)" \
  0xAddr1 0xAddr2 \
  --rpc-url $RPC_URL \
  --broadcast \
  --ledger \
  --sender <YOUR_LEDGER_ADDRESS> \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

## CLI Flag Reference

| Flag | Purpose |
|------|---------|
| `--sig "run(...)"` | Function signature with param types |
| `--rpc-url` | Network RPC endpoint |
| `--broadcast` | Actually send transactions |
| `--ledger` | Use hardware wallet |
| `--sender` | Specify which ledger account |
| `--verify` | Verify on block explorer |
| `--etherscan-api-key` | API key for verification |
| `-vvvv` | Verbose output for debugging |

## Post-Deployment Checklist

- [ ] Verify address appears in `broadcast/[Script]/[ChainId]/run-latest.json`
- [ ] Update README.md if it's a new contract type
- [ ] Add as VRF consumer on Chainlink dashboard (if VRF contract)
- [ ] Test basic interaction with `cast`

## Testing with Cast

```bash
# Check contract exists
cast code <ADDRESS> --rpc-url $RPC_URL

# Call view function
cast call <ADDRESS> "functionName()" --rpc-url $RPC_URL

# Send transaction (with ledger)
cast send <ADDRESS> "functionName(args)" \
  --rpc-url $RPC_URL \
  --ledger
```

## MonsterBattleGame Deployment

### Constructor Args
```solidity
constructor(
    address _gameEngine,
    address payable _playerContract,
    address _monsterContract,
    address vrfCoordinator,
    uint256 _subscriptionId,
    bytes32 _keyHash,
    address _playerTickets
)
```

### Find Required Addresses
```bash
# GameEngine
cat broadcast/GameEngineDeploy.s.sol/84532/run-latest.json | jq '.transactions[0].contractAddress'

# Player (payable)
cat broadcast/FighterDeploy.s.sol/84532/run-latest.json | jq '.transactions[] | select(.contractName=="Player") | .contractAddress'

# Monster
cat broadcast/FighterDeploy.s.sol/84532/run-latest.json | jq '.transactions[] | select(.contractName=="Monster") | .contractAddress'

# PlayerTickets
cat broadcast/FighterDeploy.s.sol/84532/run-latest.json | jq '.transactions[] | select(.contractName=="PlayerTickets") | .contractAddress'

# VRF Coordinator and KeyHash - see networks.md
```

### Deploy Command Template
```bash
forge script script/deploy/MonsterBattleGameDeploy.s.sol \
  --sig "run(address,address,address,address,uint256,bytes32,address)" \
  <GAME_ENGINE> \
  <PLAYER> \
  <MONSTER> \
  <VRF_COORDINATOR> \
  <SUBSCRIPTION_ID> \
  <KEY_HASH> \
  <PLAYER_TICKETS> \
  --rpc-url $RPC_URL \
  --broadcast \
  --ledger \
  --sender <LEDGER_ADDRESS>
```

### Post-Deploy Steps
1. Add MonsterBattleGame to VRF subscription as consumer
2. Contract whitelists itself in Player (if deploy script does this)
3. Call `addMonsterAvailability()` to enable monsters per difficulty tier
