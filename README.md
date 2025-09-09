# Heavy Helms v2 - Progression

## Deployed Contract Addresses - Base Sepolia

- GameEngine: 0xC128bCd9b18782c69dFA7b4Bdce61D6B6E3A1A96 v1.0
- EquipmentRequirements: 0xde2bE2739bB1350Be75cf671d0657FD51aD02E8C
- PlayerSkinRegistry: 0x9D371Aac24d54b397e9CBCdf048681BF17F12716
- PlayerNameRegistry: 0x0b7529Fb5BE5485e8799F13F079d1eB2b65FeCf7
- MonsterNameRegistry: 0x09CdBd3763d9Eec6d7AC35EC312859D0Ee40158F
- PlayerTickets: 0x73c6149A5AEA3569516dB6FCD87D4dc4AA143054
- Player: 0x5C716544Ad465cEABc0Be10c204E76BC761f9D56
- DefaultPlayer: 0x3554BFC5d5A95A9ae1139d9dBa7160EFDeA781F9
- Monster: 0xCfb1580C3E0624e960FedaE72Fb342602FBc2e5f
- DefaultPlayerSkinNFT: 0xb243A7C288121EC15eede321710Ba57298DBcCc3
- MonsterSkinNFT: 0xf9C8a0178C83c040C24fc0Af9b3D73f4fc30Ac7f
- PracticeGame: 0x5365DdbdD130B070928B8713BC79A5fe67564cA4
- DuelGame: 0x5DaCCD177e362c136103c7A3B169589Bc7b25567
- GauntletGame: 0x71AD5e337EfA81FDe0eB737aB17342F25FE4C93b (levels 1-4)
- GauntletGame: 0xf1639B58aF4cf0097b253c13Ec229082826224ca (levels 5-9)
- GauntletGame: 0x757BCCee1AAf9fb7C44ac1CE8bEdd434f71a2C0e (level 10)
- TournamentGame: 0x0Fda98b3167e35A6c01d2D38DEa4945CaEc908da

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

1. PlayerDataCodec helper contract
2. PlayerTickets contract (requires nameRegistry)
3. Player contract (with references to PlayerTickets, PlayerCreation, and PlayerDataCodec)
4. DefaultPlayer and Monster contracts
5. Default skin NFTs and registry setup

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
