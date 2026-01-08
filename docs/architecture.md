# Heavy Helms Architecture

## Core Contract Structure

### Fighter System (`src/fighters/`)

- `Fighter.sol`: Base contract for all fighter types
- `Player.sol`: Main player characters owned by users
- `DefaultPlayer.sol`: AI-controlled default players
- `Monster.sol`: Enemy monsters for PvE content

### Game Engine (`src/game/`)

- `GameEngine.sol`: Core combat mechanics and battle resolution (version 1.2)
- `EquipmentRequirements.sol`: Equipment validation and requirements
- Game Modes: `BaseGame.sol`, `PracticeGame.sol`, `DuelGame.sol`, `GauntletGame.sol`

### NFT System (`src/nft/`)

- `GameOwnedNFT.sol`: Base NFT contract
- Skin NFTs: `DefaultPlayerSkinNFT.sol`, `MonsterSkinNFT.sol`, `PlayerSkinNFT.sol`

### Registry System (`src/fighters/registries/`)

- `PlayerSkinRegistry.sol`: Manages skin collections and validation
- `PlayerNameRegistry.sol`, `MonsterNameRegistry.sol`: Name generation systems

## Key Design Patterns

### Randomness Systems

- **GauntletGame**: Uses blockhash-based commit-reveal for security and gas efficiency
- **Other Games**: Use Chainlink VRF for on-chain randomness
- Mock system available for testing (Chainlink VRF v2.5 mocks)

### Fighter ID Ranges

- Default Players: 1-2000 (game owned)
- Monsters: 2001-10000 (game owned)
- Players: 10001+ (user owned)

### Combat System

- Turn-based combat with stamina management
- Multiple combat results (miss, attack, crit, block, counter, etc.)
- Equipment affects combat outcomes

### VRF/Randomness Patterns

- GauntletGame: Blockhash-based commit-reveal
- Other Games: Chainlink VRF
- Clear phase management for multi-step processes

### Registry Pattern

- External registries for skins, names, etc.
- Validation through registry interfaces

## Security Considerations

### Checks-Effects-Interactions Pattern

Always followed for reentrancy protection

### Access Control

Owner-based permissions, whitelisting for games

### VRF Security

Proper validation of VRF responses

### Fee Handling

Careful arithmetic to prevent overflow/underflow

## Common Patterns

### Error Handling

Custom errors used throughout

### Events

Comprehensive events for all state changes

### Modifiers

Common validation in modifiers

### Libraries

Extensive use of libraries for code reuse and gas optimization

## Current Development Priorities

### Completed

- **Blockhash Gauntlet System**: Complete 3-transaction commit-reveal implementation
  - Queue selection timing exploit FIXED
  - VRF costs eliminated (50%+ gas savings)
  - Instant gauntlet completion (no VRF delays)
  - Comprehensive test coverage (23/23 tests passing)
- **GameEngine v1.2 Weapon Classification System**: Complete rebalancing with attribute-based damage scaling
  - 7 weapon classes with unique damage formulas (e.g., Light Finesse uses pure AGI×10)
  - Universal size damage bonus system affects all weapons
  - Shield principle properly implemented (defense trades for offense)
  - Level progression system with XP, attribute points, and damage/health scaling
  - Weapon and armor specialization systems
- **Enhanced Stamina System**: Stamina ramp-up with negative effects under 50%
- All ticket types working correctly (Type 1-4)
- 64-player gauntlet support (~15M gas, well under 30M block limit)

### Current Focus: Post v1.2 Balance Testing

- v1.2 GameEngine implemented with full level progression (1-10)
- Level benefits: +5% health/damage per level, +2 initiative, +1 attribute point
- Weapon and armor specialization systems unlock at levels 10 and 5
- Monitoring archetype balance across all levels
