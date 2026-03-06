# Heavy Helms Architecture

## Contract Structure

### Fighter System (`src/fighters/`)

- `Fighter.sol`: Base contract, defines shared structs (PlayerLoadout, SkinInfo, FighterStats)
- `Player.sol`: User-owned fighters. Soulbound mappings, VRF-based creation, XP/leveling, attribute allocation
- `DefaultPlayer.sol`: Game-owned AI fighters (IDs 1-2000) used to fill gauntlet/tournament brackets
- `Monster.sol`: PvE enemies (IDs 2001-10000) with predefined stat templates

### Game Engine (`src/game/`)

- `GameEngine.sol` (v1.2): Core combat simulation. Resolves fights purely onchain, outputs bit-packed combat logs
- `EquipmentRequirements.sol`: Validates weapon/armor combinations against fighter stats
- `BaseGame.sol`: Abstract base for all game modes
- `PracticeGame.sol`: Free play against default players and monsters
- `DuelGame.sol`: 1v1 challenge-accept PvP via Chainlink VRF
- `GauntletGame.sol`: Elimination brackets (4-32 players) via blockhash commit-reveal
- `TournamentGame.sol`: Scheduled daily tournaments (16-32 players) with death mechanics and rewards
- `MonsterBattleGame.sol`: PvE progression via Chainlink VRF

### NFT System (`src/nft/`)

- `GameOwnedNFT.sol`: Base ERC-721 (Solady) for game-managed NFTs
- `PlayerSkinNFT.sol`: Tradeable ERC-721 skins that define weapon + armor loadouts
- `DefaultPlayerSkinNFT.sol`, `MonsterSkinNFT.sol`: Game-owned skin sets
- `UnlockableKeyNFT.sol`: Key-gated skin unlocks
- `PlayerTickets.sol`: ERC-1155 (Solady) utility tickets (stat respec, new fighter, roster slot, daily resets)

### Registry System (`src/fighters/registries/`)

- `PlayerSkinRegistry.sol`: Manages skin collections, validates ownership and equipment compatibility
- `PlayerNameRegistry.sol`, `MonsterNameRegistry.sol`: Onchain name generation from predefined word lists

### Libraries (`src/lib/`)

- `PlayerDataCodec.sol`: Bit-packing for player attributes into efficient storage
- `UniformRandomNumber.sol`: Uniform random number generation within ranges
- `DefaultPlayerLibrary.sol`, `MonsterLibrary.sol`: Predefined fighter templates

## Randomness

Two distinct approaches based on game mode requirements:

### Blockhash Commit-Reveal (Gauntlets, Tournaments)

Three-transaction flow for high-frequency game modes where VRF latency and cost are impractical:

1. **Commit**: Records current block number, locks queue state
2. **Select**: At future block, uses `blockhash` to randomly select participants from queue
3. **Execute**: At another future block, uses `blockhash` as combat seed, runs full bracket

Tradeoff: Base uses a centralized sequencer, so the sequencer could theoretically influence outcomes. Accepted because entry values are low and the UX benefit (instant resolution, no VRF callback delay) outweighs the risk.

### Chainlink VRF v2.5 (Player Creation, Duels, Monster Battles)

Standard request-callback pattern for operations where latency is acceptable and provable fairness matters more:

- Player creation: random stat distribution
- Duels: combat resolution seed
- Monster battles: combat resolution seed

## Fighter ID Ranges

| Range | Type | Contract |
|---|---|---|
| 1-2000 | Default Players | DefaultPlayer (game-owned) |
| 2001-10000 | Monsters | Monster (game-owned) |
| 10001+ | Players | Player (user-owned) |

## Combat Log Format

Binary-encoded for gas efficiency and frontend replay:

- Byte 0-3: `uint32` packed winner + win condition
- Byte 4: header flags
- Bytes 5+: 8 bytes per combat action, containing both players' results per round
- Damage values packed as `uint16`

The frontend decodes this byte array and replays the fight visually.

## Access Control

Owner-based via OpenZeppelin Ownable. Game contracts are granted specific permissions on the Player contract:

```
GamePermissions {
    record: bool,   // Can record wins/losses
    retire: bool,   // Can kill fighters (tournaments only)
    immortal: bool, // Fighters can't die in this mode
    experience: bool // Can award XP
}
```

PlayerTickets has its own permission system controlling which game contracts can mint which ticket types.

## Season System

Time-bounded competition periods using BokkyPooBah's DateTime library. Seasons gate tournament participation and track per-season rankings. Season transitions reset certain progression metrics while preserving permanent fighter state (level, attributes).
