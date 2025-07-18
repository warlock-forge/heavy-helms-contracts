# Heavy Helms

## Deployed Contract Addresses - Shape Mainnet

- GameEngine: 0x60567795F7a60986204A5507538600b53adeE42a
- EquipmentRequirements: 0xEE4A523BB2762D0556e20F857FE95f9384f7b578
- PlayerSkinRegistry: 0x70FA59BA4FbD253850c76B6d1A12a7DFaC744072
- PlayerNameRegistry: 0x9e0183eD52B3A3c934879f6Ff13dC8811ED20f1c
- MonsterNameRegistry: 0xcEE41C17c8797EAc2DD8aB1425F0e3c73f97EF0a
- **PlayerCreation: [DEPLOY_NEW]** *(New helper contract for player stat generation)*
- **PlayerDataCodec: [DEPLOY_NEW]** *(New helper contract for data encoding/decoding)*
- **PlayerTickets: [DEPLOY_NEW]** *(New ERC1155 burnable ticket system)*
- Player: 0x75B4750D41A9a04e989FAD58544C37930AEf2e5B *(NEEDS REDEPLOYMENT - new constructor params)*
- DefaultPlayer: 0x4745bfCD3B6e785C44B47FD871CdbA8283fe94BC
- Monster: 0x9f742615fA8ae9Caa001C658Aa8000aC7506F24c
- DefaultPlayerSkinNFT: 0x5540De99D291f9C149430aB22071332c383A0711
- MonsterSkinNFT: 0xb48Abb150834EBA4912BF2D5f6544Dc24b8C2d87
- UnlockablePlayerSkinNFT: 0xf32764F7C5205662221e008c2099C1d81F7AA846
- PracticeGame: 0xee5Ccf602AA0E5ff1C6F78CAB3AaC0dA317aF0b3
- DuelGame: 0x805b44fadbCBA7a65b37875551820593a45a8716 *(May need redeployment if using codec directly)*
- GauntletGame: 0x684055392575eF42A6f04490dB50FFdC34309681 *(May need redeployment if using codec directly)*

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

## .env file
```
RPC_URL=<YOUR RPC URL> // Optional - will use forked chain for entropy during testing
PK=<YOUR PRIVATE KEY> // Only needed for deployment + scripts
GELATO_VRF_OPERATOR=<YOUR GELATO VRF OPERATOR> // Only needed for deployment
```

## Usage Scripts

- Create Player: *(add --broadcast to send tx)*
```bash
forge script script/game/player/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE>
```
- Equip Skin: *(add --broadcast to send tx)*
```bash
forge script script/game/player/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID>
```

- Duel Players (both should be owned by PK): *(add --broadcast to send tx)*
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
forge install --no-git foundry-rs/forge-std@1eea5ba transmissions11/solmate@c93f771 gelatodigital/vrf-contracts@fdb85db
```
3. Deploy GameEngine contract *(add --broadcast to send tx)*
```bash
forge script script/deploy/GameEngineDeploy.s.sol
```
4. Deploy EquipmentRequirements contract *(add --broadcast to send tx)*
```bash
forge script script/deploy/EquipmentRequirementsDeploy.s.sol
```
5. Deploy PlayerSkinRegistry: *(add --broadcast to send tx)*
```bash
forge script script/deploy/PlayerSkinRegistryDeploy.s.sol
```
6. Deploy NameRegistry: *(add --broadcast to send tx)*
```bash
forge script script/deploy/NameRegistryDeploy.s.sol
```
7. Deploy PlayerTickets: *(add --broadcast to send tx)*
```bash
forge script script/deploy/PlayerTicketsDeploy.s.sol
```
8. Deploy PlayerCreation Helper: *(add --broadcast to send tx)*
```bash
forge script script/deploy/PlayerCreationDeploy.s.sol --sig "run(address)" <PLAYER_NAME_REGISTRY_ADDRESS>
```
9. Deploy PlayerDataCodec Helper: *(add --broadcast to send tx)*
```bash
forge script script/deploy/PlayerDataCodecDeploy.s.sol
```
10. Deploy Fighter: *(add --broadcast to send tx)*
```bash
forge script script/deploy/FighterDeploy.s.sol --sig "run(address,address,address,address)" <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> <EQUIPMENT_REQUIREMENTS_ADDRESS>
```

**Note:** The FighterDeploy script now requires additional dependencies and will deploy in this order:
1. PlayerCreation helper contract
2. PlayerDataCodec helper contract  
3. Player contract (with references to PlayerTickets, PlayerCreation, and PlayerDataCodec)
4. DefaultPlayer and Monster contracts
5. Default skin NFTs and registry setup

**Updated FighterDeploy Parameters:**
The script internally handles the new helper contract deployments, but the Player contract now requires:
- PlayerTickets address (for burnable ticket system)
- PlayerCreation address (for stat generation)
- PlayerDataCodec address (for data encoding/decoding)

11. Deploy Unlockable Skin Collection (Optional): *(add --broadcast to send tx)*
```bash
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS>
```
12. Deploy PracticeGame *(add --broadcast to send tx)*
```bash
forge script script/deploy/PracticeGameDeploy.s.sol --sig "run(address,address,address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS>
```
13. Deploy DuelGame *(add --broadcast to send tx)*
```bash
forge script script/deploy/DuelGameDeploy.s.sol --sig "run(address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS>
```
14. Deploy GauntletGame *(add --broadcast to send tx)*
```bash
forge script script/deploy/GauntletGameDeploy.s.sol --sig "run(address,address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS>
```
15. Setup VRF
```bash
Use Gelato dashboard to add VRF tasks for Player + Duel Game + Gauntlet Game contracts
```

## Architecture Changes - Contract Size Optimization

**Important:** This version includes significant architectural changes to reduce the Player contract size:

### New Helper Contracts
- **PlayerCreation**: Handles player stat generation and name assignment (pure functions extracted from Player)
- **PlayerDataCodec**: Handles encoding/decoding of player data for game modes (pure functions extracted from Player)  
- **PlayerTickets**: ERC1155 burnable ticket system replacing charge mappings

### Contract Size Impact
- **Player contract**: Reduced from 27,559 bytes to 20,500 bytes (4,076 bytes under EIP-170 limit)
- **Total helper contracts**: 7,463 bytes across 3 deployable contracts
- **Net architecture cost**: 3,115 bytes spread across multiple contracts vs monolithic approach

### Key Changes
1. **Player Creation**: Now uses external PlayerCreation contract for stat generation
2. **Data Encoding**: Game modes access codec via `player.codec().encodePlayerData()`
3. **Ticket System**: NFT-based burnable tickets replace charge mappings for name changes, attribute swaps, etc.
4. **Trustless Design**: All helper contracts use immutable addresses - no admin control

### Test

```shell
$ forge test
```

