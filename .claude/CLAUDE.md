# Heavy Helms

Solidity-based on-chain game featuring combat mechanics, NFT skins, and multiple game modes. Built with Foundry. Gauntlet tournaments use blockhash-based randomness for security and gas efficiency. Other game modes use Chainlink VRF.

## Key Commands

### Build

```bash
forge build
```

### Test

```bash
forge test                    # Run unit tests only (default profile excludes test/simulation/)
forge test -vv               # Run with verbose output
forge test --match-test      # Run specific test function
forge test --match-contract  # Run specific test contract

# Simulation tests (balance, progression, lethality, tournament gas)
FOUNDRY_PROFILE=simulation forge test -vv
```

### Deployment & Scripts

```bash
forge script <script-path> --broadcast    # Deploy/execute with transaction
forge script <script-path>                # Dry run without broadcasting
```

### Code Quality

```bash
forge fmt         # Format Solidity code
forge coverage    # Generate test coverage report
```

## Fighter ID Ranges

- Default Players: 1-2000 (game owned)
- Monsters: 2001-10000 (game owned)
- Players: 10001+ (user owned)

## Environment Setup

```bash
forge install --no-git foundry-rs/forge-std@1eea5ba bokkypoobah/BokkyPooBahsDateTimeLibrary@1dc26f9 vectorized/solady@v0.1.24 smartcontractkit/chainlink-evm@v0.3.2 OpenZeppelin/openzeppelin-contracts@v4.9.6
```

## Configuration (.env file)

```
RPC_URL=<YOUR RPC URL>
PK=<YOUR PRIVATE KEY>
```

## Deployment Order

GameEngine → EquipmentRequirements → Registries → Fighters → Games

## Critical Memories

- Via IR is enabled in foundry.toml - compilation is slow.
- Solady is the primary dependency for gas-optimized contracts.

## Reference Documentation

- For combat mechanics, archetypes, weapon formulas: read `docs/game-mechanics.md`
- For contract structure and design patterns: read `docs/architecture.md`
- For development workflow and optimization: read `docs/development.md`
