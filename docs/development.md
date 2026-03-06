# Development

## Build

```bash
forge build
```

`via_ir` is enabled in foundry.toml. Compilation is slow but produces optimized bytecode.

## Test

```bash
forge test                    # Unit tests only (default profile excludes test/simulation/)
forge test -vv                # Verbose output
forge test --match-test       # Run specific test function
forge test --match-contract   # Run specific test contract
```

### Simulation Tests

Non-deterministic combat simulations live in `test/simulation/`. These run hundreds of fights and assert statistical outcomes (win rates within ranges, progression scaling, gas limits):

```bash
FOUNDRY_PROFILE=simulation forge test -vv
FOUNDRY_PROFILE=simulation forge test -vv --match-contract BalanceTest
```

The default Foundry profile excludes `test/simulation/*` via `no_match_path` in `foundry.toml`.

## Coverage

```bash
forge coverage --ir-minimum --report summary --report lcov
```

CI filters out `test/` and `script/` from the LCOV report and enforces a 90% minimum gate.

## Formatting

```bash
forge fmt           # Format
forge fmt --check   # Check only (CI runs this)
```

## Static Analysis

Both run in CI on every push/PR:

```bash
pip install slither-analyzer
slither .

# Aderyn runs via GitHub Action (Cyfrin/aderyn-ci)
```

False positives are suppressed inline:
- Slither: `// slither-disable-next-line <detector>`
- Aderyn: `// aderyn-fp` on the same line as the finding

## Dependencies

Installed via forge with pinned versions:

```bash
forge install --no-git foundry-rs/forge-std@v1.15.0 bokkypoobah/BokkyPooBahsDateTimeLibrary@1dc26f9 vectorized/solady@v0.1.24 smartcontractkit/chainlink-evm@v0.3.2 OpenZeppelin/openzeppelin-contracts@v4.9.6
```

Remappings are in `foundry.toml`, not `remappings.txt`.

## Gas Optimization Notes

- Solady ERC-721 and ERC-1155 over OpenZeppelin equivalents
- `PlayerDataCodec` bit-packs 6 attributes + metadata into minimal storage slots
- Combat logs use custom binary encoding (8 bytes per action) instead of structs/events
- `via_ir` optimizer enabled with 200 runs
- Storage variables packed where possible (uint8, uint32 grouped in structs)

## Project Structure

```
src/
  fighters/          # Player, Monster, DefaultPlayer, registries
  game/
    engine/          # GameEngine, EquipmentRequirements
    modes/           # PracticeGame, DuelGame, GauntletGame, TournamentGame, MonsterBattleGame
  interfaces/        # All contract interfaces
  lib/               # PlayerDataCodec, UniformRandomNumber, fighter libraries
  nft/               # PlayerSkinNFT, PlayerTickets, GameOwnedNFT, UnlockableKeyNFT
test/
  fighters/          # Player, Monster, registry tests
  game/              # Game mode tests, gas analysis
  nft/               # NFT and ticket tests
  simulation/        # Balance, progression, lethality, gas simulations
  helpers/           # Test utilities (reentrancy attacker, malicious receivers)
  mocks/             # Mock contracts for testing
script/
  deploy/            # Deployment scripts
  game/              # Usage scripts (create player, equip skin, duel)
  admin/             # Admin operation scripts
```
