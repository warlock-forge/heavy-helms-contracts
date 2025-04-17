# Heavy Helms

## Deployed Contract Addresses - Shape Mainnet

- GameEngine: 0x60567795F7a60986204A5507538600b53adeE42a
- EquipmentRequirements: 0xEE4A523BB2762D0556e20F857FE95f9384f7b578
- PlayerSkinRegistry: 0x70FA59BA4FbD253850c76B6d1A12a7DFaC744072
- PlayerNameRegistry: 0x9e0183eD52B3A3c934879f6Ff13dC8811ED20f1c
- MonsterNameRegistry: 0xcEE41C17c8797EAc2DD8aB1425F0e3c73f97EF0a
- Player: 0x75B4750D41A9a04e989FAD58544C37930AEf2e5B
- DefaultPlayer: 0x4745bfCD3B6e785C44B47FD871CdbA8283fe94BC
- Monster: 0x9f742615fA8ae9Caa001C658Aa8000aC7506F24c
- DefaultPlayerSkinNFT: 0x5540De99D291f9C149430aB22071332c383A0711
- MonsterSkinNFT: 0xb48Abb150834EBA4912BF2D5f6544Dc24b8C2d87
- UnlockablePlayerSkinNFT: 0xf32764F7C5205662221e008c2099C1d81F7AA846
- PracticeGame: 0xee5Ccf602AA0E5ff1C6F78CAB3AaC0dA317aF0b3
- DuelGame: 0x805b44fadbCBA7a65b37875551820593a45a8716

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
forge install
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
7. Deploy Fighter: *(add --broadcast to send tx)*
```bash
forge script script/deploy/FighterDeploy.s.sol --sig "run(address,address,address,address)" <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> <EQUIPMENT_REQUIREMENTS_ADDRESS>
```
8. Deploy Unlockable Skin Collection (Optional): *(add --broadcast to send tx)*
```bash
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS>
```
9. Deploy PracticeGame *(add --broadcast to send tx)*
```bash
forge script script/deploy/PracticeGameDeploy.s.sol --sig "run(address,address,address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS>
```
10. Deploy DuelGame *(add --broadcast to send tx)*
```bash
forge script script/deploy/DuelGameDeploy.s.sol --sig "run(address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS>
```
11. Setup VRF
```bash
Use Gelato dashboard to add VRF tasks for Player + Duel Game contracts
```

### Test

```shell
$ forge test
```

