<p align="center">
  <img src="https://app.heavyhelms.xyz/heavy_helms_header.png" alt="Heavy Helms" width="600" />
</p>

<p align="center">
  <strong>An auto-battler RPG built entirely in Solidity.</strong>
</p>

<p align="center">
  <a href="https://farcaster.xyz/miniapps/uky1-yNerDOD/heavy-helms">Farcaster Miniapp</a> &middot;
  <a href="https://app.heavyhelms.xyz">Web App</a> &middot;
  <a href="https://heavyhelms.xyz/sunset">Origins (Archived)</a> &middot;
  <a href="#documentation">Documentation</a>
</p>

---

Create a warrior, allocate stats, equip skins that change how they fight, and battle through duels, gauntlets, and tournaments. All resolved by the smart contract, not an off-chain server. Combat logs are bit-packed into bytes for frontend replay. The EVM is the game engine.

Production contracts deployed on Base mainnet with a Farcaster miniapp frontend. Earlier version (Heavy Helms Origins) ran on Shape Network with 54,000+ onchain fights across 450+ unique players. [[Dune](https://dune.com/webmodularity/heavy-helms-origins)]

## Technical Overview

### Combat Engine

The entire combat simulation runs in the EVM. A single `GameEngine` contract resolves fights for all game modes: practice, duels, gauntlets, tournaments, and monster battles. New modes deploy without touching player data.

Combat logs use a custom binary format: 4-byte header (winner, engine version, win condition), then 8 bytes per combat action with `uint16` damage packing. The frontend decodes and replays fights from this byte array.

### Fighter System

Warriors are soulbound contract mappings, not NFTs. You can't buy your way to the top. Stats are bit-packed via `PlayerDataCodec` for efficient storage. Every fighter is created with 72 attribute points randomly distributed across 6 stats (range 3-21 each).

ERC-721 skins alter combat strategy by changing weapon and armor loadouts. Skins are tradeable; fighters are not. A stance system (offensive / balanced / defensive) layers on top of skin choice.

### Randomness

- Gauntlets & Tournaments: Blockhash commit-reveal with multi-phase entropy. No VRF overhead for high-frequency game modes.
- Player Creation, Duels & Monster Battles: Chainlink VRF v2.5 for random stat rolls and combat resolution seeds.

### Progression (v2)

- XP and leveling across all game modes (+1 allocatable attribute point per level)
- Season system with time-bounded competition
- Gauntlet difficulty tiers gated by player level (L1-4, L5-9, L10)
- Rewards are in-game utility tickets only: stat respec, new fighter rolls, roster expansion.

### Stack

- [Foundry](https://book.getfoundry.sh/) for build, test, and deployment
- [Solady](https://github.com/vectorized/solady) for gas-optimized ERC-721, ERC-1155, and utilities
- [Chainlink VRF v2.5](https://docs.chain.link/vrf) for verifiable randomness
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) for access control

## By the Numbers

|                     |                                                                                 |
| ------------------- | ------------------------------------------------------------------------------- |
| Production Solidity | 14k+ lines across 39 contracts                                                  |
| Test Code           | 18k+ lines (1.3:1 test-to-source ratio)                                         |
| CI Pipeline         | fmt check, unit tests, 90% LCOV coverage gate, Slither + Aderyn static analysis |
| Verified Contracts  | 16+ on Base mainnet                                                             |
| Audit Status        | Self-audited with Slither + Aderyn in CI. No formal external audit.             |

## Gas Profile

All combat runs onchain. Gas totals include the full 3-transaction blockhash commit-reveal flow (commit, participant selection, execution). Duels use Chainlink VRF instead.

| Mode | Players | Gas Used |
|---|---|---|
| Duel (VRF) | 2 | ~306k |
| Gauntlet | 4 | 2.1M |
| Gauntlet | 8 | 4.1M |
| Gauntlet | 16 | 8.2M |
| Gauntlet | 32 | 16.0M |
| Tournament | 16 | 8.5M |
| Tournament | 32 | 16.2M |

## Deployed Contracts

### Base Mainnet (v2)

| Contract              | Address                                                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| GameEngine v1.2       | [`0xD351cF16cBc8A8732D6E5aB46B3d8b350075567a`](https://basescan.org/address/0xD351cF16cBc8A8732D6E5aB46B3d8b350075567a) |
| EquipmentRequirements | [`0xB7710a3C16f71bD46E174E5806F4274Cbc934837`](https://basescan.org/address/0xB7710a3C16f71bD46E174E5806F4274Cbc934837) |
| PlayerSkinRegistry    | [`0xA308ECAD719A4d8708462318727a6001e6604f10`](https://basescan.org/address/0xA308ECAD719A4d8708462318727a6001e6604f10) |
| PlayerNameRegistry    | [`0x6106E1f3De585b968CEAa4b9f732cCd201aD9811`](https://basescan.org/address/0x6106E1f3De585b968CEAa4b9f732cCd201aD9811) |
| MonsterNameRegistry   | [`0xFB1C764754BD6D32DF5FAaf9378e3e969AF57535`](https://basescan.org/address/0xFB1C764754BD6D32DF5FAaf9378e3e969AF57535) |
| PlayerDataCodec       | [`0x8d620198c96682c11D69CE26600e5FC823d6b763`](https://basescan.org/address/0x8d620198c96682c11D69CE26600e5FC823d6b763) |
| Player                | [`0xb19f2D8e0f3Fd0111CA49dc5ae2f656972B6Df4c`](https://basescan.org/address/0xb19f2D8e0f3Fd0111CA49dc5ae2f656972B6Df4c) |
| PlayerTickets         | [`0x19AAb75Dc28340a163b3856Ae3Ce698277dfD339`](https://basescan.org/address/0x19AAb75Dc28340a163b3856Ae3Ce698277dfD339) |
| DefaultPlayer         | [`0xc520795Cb19aE57A1aF91EdDDA637Ea852E262B9`](https://basescan.org/address/0xc520795Cb19aE57A1aF91EdDDA637Ea852E262B9) |
| Monster               | [`0x9c586B69b63c775f05d3c2590c4C2C06D2D6ABE1`](https://basescan.org/address/0x9c586B69b63c775f05d3c2590c4C2C06D2D6ABE1) |
| DefaultPlayerSkinNFT  | [`0x2af065B73940Be500A38F4CE63EFE4a6bf3A81D4`](https://basescan.org/address/0x2af065B73940Be500A38F4CE63EFE4a6bf3A81D4) |
| MonsterSkinNFT        | [`0x83d7A13457df1cb1a9c8E29dEE62078a1a7cacf2`](https://basescan.org/address/0x83d7A13457df1cb1a9c8E29dEE62078a1a7cacf2) |
| PracticeGame          | [`0x4A72CD0d147Af3923bCa35a0097Be9e8711789ac`](https://basescan.org/address/0x4A72CD0d147Af3923bCa35a0097Be9e8711789ac) |
| DuelGame              | [`0x595C77EFce088936e7E1E94432732984b30a1CAc`](https://basescan.org/address/0x595C77EFce088936e7E1E94432732984b30a1CAc) |
| GauntletGame (L1-4)   | [`0x005744D889870E6de3c5cC0a4537B88034620416`](https://basescan.org/address/0x005744D889870E6de3c5cC0a4537B88034620416) |
| GauntletGame (L5-9)   | [`0x4D31cA1dC8664d26e9AC4A50B4483Ce715BD6EBc`](https://basescan.org/address/0x4D31cA1dC8664d26e9AC4A50B4483Ce715BD6EBc) |
| GauntletGame (L10)    | [`0x2Ff94A1F55fE00bE2b540CB1e6BEDb0712f7E73E`](https://basescan.org/address/0x2Ff94A1F55fE00bE2b540CB1e6BEDb0712f7E73E) |

### Shape Network (Origins v0.5.5)

The original deployment. 54,000+ onchain fights, 700+ fighters created, 450+ unique players.

| Contract       | Address                                                                                                                  |
| -------------- | ------------------------------------------------------------------------------------------------------------------------ |
| GameEngine v28 | [`0xdeaeC1c6d410adD4713c4C4F3623E133d5B1C8d4`](https://shapescan.xyz/address/0xdeaeC1c6d410adD4713c4C4F3623E133d5B1C8d4) |
| Player         | [`0x75B4750D41A9a04e989FAD58544C37930AEf2e5B`](https://shapescan.xyz/address/0x75B4750D41A9a04e989FAD58544C37930AEf2e5B) |
| DefaultPlayer  | [`0x4745bfCD3B6e785C44B47FD871CdbA8283fe94BC`](https://shapescan.xyz/address/0x4745bfCD3B6e785C44B47FD871CdbA8283fe94BC) |
| Monster        | [`0x9f742615fA8ae9Caa001C658Aa8000aC7506F24c`](https://shapescan.xyz/address/0x9f742615fA8ae9Caa001C658Aa8000aC7506F24c) |
| PracticeGame   | [`0xee5Ccf602AA0E5ff1C6F78CAB3AaC0dA317aF0b3`](https://shapescan.xyz/address/0xee5Ccf602AA0E5ff1C6F78CAB3AaC0dA317aF0b3) |
| DuelGame       | [`0x805b44fadbCBA7a65b37875551820593a45a8716`](https://shapescan.xyz/address/0x805b44fadbCBA7a65b37875551820593a45a8716) |
| GauntletGame   | [`0x684055392575eF42A6f04490dB50FFdC34309681`](https://shapescan.xyz/address/0x684055392575eF42A6f04490dB50FFdC34309681) |

<details>
<summary>All Shape Network addresses</summary>

| Contract                | Address                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| EquipmentRequirements   | [`0xEE4A523BB2762D0556e20F857FE95f9384f7b578`](https://shapescan.xyz/address/0xEE4A523BB2762D0556e20F857FE95f9384f7b578) |
| PlayerSkinRegistry      | [`0x70FA59BA4FbD253850c76B6d1A12a7DFaC744072`](https://shapescan.xyz/address/0x70FA59BA4FbD253850c76B6d1A12a7DFaC744072) |
| PlayerNameRegistry      | [`0x9e0183eD52B3A3c934879f6Ff13dC8811ED20f1c`](https://shapescan.xyz/address/0x9e0183eD52B3A3c934879f6Ff13dC8811ED20f1c) |
| MonsterNameRegistry     | [`0xcEE41C17c8797EAc2DD8aB1425F0e3c73f97EF0a`](https://shapescan.xyz/address/0xcEE41C17c8797EAc2DD8aB1425F0e3c73f97EF0a) |
| DefaultPlayerSkinNFT    | [`0x5540De99D291f9C149430aB22071332c383A0711`](https://shapescan.xyz/address/0x5540De99D291f9C149430aB22071332c383A0711) |
| MonsterSkinNFT          | [`0xb48Abb150834EBA4912BF2D5f6544Dc24b8C2d87`](https://shapescan.xyz/address/0xb48Abb150834EBA4912BF2D5f6544Dc24b8C2d87) |
| UnlockablePlayerSkinNFT | [`0xf32764F7C5205662221e008c2099C1d81F7AA846`](https://shapescan.xyz/address/0xf32764F7C5205662221e008c2099C1d81F7AA846) |

</details>

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

### Install

```bash
git clone https://github.com/warlock-forge/heavy-helms-contracts.git
cd heavy-helms-contracts
forge install --no-git foundry-rs/forge-std@v1.15.0 bokkypoobah/BokkyPooBahsDateTimeLibrary@1dc26f9 vectorized/solady@v0.1.24 smartcontractkit/chainlink-evm@v0.3.2 OpenZeppelin/openzeppelin-contracts@v4.9.6
```

### Build & Test

```bash
forge build                   # Build (via_ir enabled, slow but optimized)
forge test                    # Unit tests (excludes simulation/)
forge test -vv                # Verbose output
forge fmt                     # Format
```

### Simulation Tests

Non-deterministic combat simulations: balance matchups, progression scaling, lethality, gas analysis. Hundreds of fights per run:

```bash
FOUNDRY_PROFILE=simulation forge test -vv
```

### Coverage

```bash
forge coverage --ir-minimum --report summary --report lcov
```

### CI Pipeline

Runs on every push and PR (`.github/workflows/ci.yml`):

1. `forge fmt --check`
2. `forge test -vv`
3. Coverage with 90% LCOV gate
4. Slither + Aderyn static analysis

### Full Deployment

See [docs/deployment.md](docs/deployment.md) for the complete deployment walkthrough.

## Documentation

- [Architecture](docs/architecture.md): contract structure and design patterns
- [Game Mechanics](docs/game-mechanics.md): combat, archetypes, weapon formulas
- [Security](docs/security.md): threat model, access control, randomness, known limitations
- [Development](docs/development.md): workflow and optimization notes
- [Deployment](docs/deployment.md): step-by-step deployment guide

## License

[GPL-3.0](LICENSE)
