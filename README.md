# Heavy Helms v2 - Progression

## Deployed Contract Addresses - Base Sepolia

- GameEngine: 0xC128bCd9b18782c69dFA7b4Bdce61D6B6E3A1A96 v1.0
- EquipmentRequirements: 0x3b448807536b95B97fEFE0EBc15489ADaE7da2aA
- PlayerSkinRegistry: 0xaA8c214bA0efFd88CdE442946B518b91a437b4e3
- PlayerNameRegistry: 0x7224Ff906a60E96725D019E84f3B23540442A898
- MonsterNameRegistry: 0xacD57159a8A02b59E923FCE01Ca8A21f16C2042A
- PlayerTickets: 0xc0e8973f7AF2e7Ab5F5749419934A04e1A90c6cB
- Player: 0x2d248A737e3eCB013e2a62fD8959a0A3D7eCf9F3
- DefaultPlayer: 0xcE8129957D8B64813D9E936921819741a54649Fc
- Monster: 0x3feae9A9788c3d48C06F15d9115fA47b536EA66F
- DefaultPlayerSkinNFT: 0x4a8b436456f12559EAb0A5Ba68E09181cEb91593
- MonsterSkinNFT: 0x31fE904307a15a24D02E711Db0cA4fbB9869BAD6
- PracticeGame: 0xa1Ff9Cf87Ec73F30d6AD5A5a963809D0806C9852
- DuelGame: 0x86f776A0d39F5640a276696A868814f99a58b4D2
- GauntletGame: 0xDF4Dca458939d95C64B5d610B6867d794C3FeC3f (levels 1-4)
- GauntletGame: 0x7AC1E825dB7501b7F886704f85d9E62B3E19DD41 (levels 5-9)
- GauntletGame: 0x6E8266C2264c84e7552DA3f4eE9DC4634a90fA7c (level 10)
- TournamentGame: 0x742af1F015920cF7eAd4ca68697c77e631489336

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

## .env file

```
RPC_URL=<YOUR RPC URL> // Optional - will use forked chain for entropy during testing
PK=<YOUR PRIVATE KEY> // Only needed for deployment + scripts
```

## Usage Scripts

- Create Player: _(add --broadcast to send tx)_

```bash
forge script script/game/player/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE>
```

- Equip Skin: _(add --broadcast to send tx)_

```bash
forge script script/game/player/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID>
```

- Duel Players (both should be owned by PK): _(add --broadcast to send tx)_

```bash
forge script script/game/duel/DuelPlayers.s.sol --sig "run(address,uint32,uint32)" <DUEL_GAME_ADDRESS> <CHALLENGER_ID> <DEFENDER_ID>
```

## Installation

1. Clone the repository:

```bash
git clone https://github.com/webmodularity/auto_battler_game_contracts.git
cd auto_battler_game_contracts
```

2. Install dependencies:

```bash
forge install --no-git foundry-rs/forge-std@1eea5ba bokkypoobah/BokkyPooBahsDateTimeLibrary@1dc26f9 vectorized/solady@v0.1.24 smartcontractkit/chainlink-evm@v0.3.2 OpenZeppelin/openzeppelin-contracts@v4.9.6
```

3. Deploy GameEngine contract _(add --broadcast to send tx)_

```bash
forge script script/deploy/GameEngineDeploy.s.sol
```

4. Deploy EquipmentRequirements contract _(add --broadcast to send tx)_

```bash
forge script script/deploy/EquipmentRequirementsDeploy.s.sol
```

5. Deploy PlayerSkinRegistry: _(add --broadcast to send tx)_

```bash
forge script script/deploy/PlayerSkinRegistryDeploy.s.sol
```

6. Deploy NameRegistry: _(add --broadcast to send tx)_

```bash
forge script script/deploy/NameRegistryDeploy.s.sol
```

7. Deploy Fighters (includes PlayerTickets and helper contracts): _(add --broadcast to send tx)_

```bash
forge script script/deploy/FighterDeploy.s.sol --sig "run(address,address,address,address,address,uint256,bytes32)" <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> <EQUIPMENT_REQUIREMENTS_ADDRESS> <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH>
```

**Note:** The FighterDeploy script now deploys multiple contracts in this order:

1. PlayerCreation helper contract
2. PlayerDataCodec helper contract
3. PlayerTickets contract (requires nameRegistry)
4. Player contract (with references to PlayerTickets, PlayerCreation, and PlayerDataCodec)
5. DefaultPlayer and Monster contracts
6. Default skin NFTs and registry setup

All contracts are deployed automatically within the FighterDeploy script - no separate deployment needed.

8. Deploy Unlockable Skin Collection (Optional): _(add --broadcast to send tx)_

```bash
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS>
```

9. Deploy PracticeGame _(add --broadcast to send tx)_

```bash
forge script script/deploy/PracticeGameDeploy.s.sol --sig "run(address,address,address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS>
```

10. Deploy DuelGame _(add --broadcast to send tx)_

```bash
forge script script/deploy/DuelGameDeploy.s.sol --sig "run(address,address,address,address,uint256,bytes32)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH>
```

11. Deploy GauntletGame _(add --broadcast to send tx)_

```bash
forge script script/deploy/GauntletGameDeploy.s.sol --sig "run(address,address,address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS>
```

12. Deploy TournamentGame _(add --broadcast to send tx)_

```bash
forge script script/deploy/TournamentGameDeploy.s.sol --sig "run(address,address,address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS>
```

13. Setup Chainlink VRF

```bash
# 1. Create a Chainlink VRF subscription on your target network
# 2. Fund the subscription with LINK tokens or native currency
# 3. Add the deployed Player + Duel contract as consumers to your subscription
# 4. Note the VRF Coordinator address, subscription ID, and key hash for deployments
```

## Architecture Changes - Contract Size Optimization

**Important:** This version includes significant architectural changes to reduce the Player contract size:

### New Helper Contracts

- **PlayerCreation**: Handles player stat generation and name assignment (pure functions extracted from Player)
- **PlayerDataCodec**: Handles encoding/decoding of player data for game modes (pure functions extracted from Player)
- **PlayerTickets**: ERC1155 burnable ticket system replacing charge mappings

### Test

```shell
$ forge test
```
