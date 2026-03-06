# Deployment Guide

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

## .env file

```
RPC_URL=<YOUR RPC URL>
ETHERSCAN_API_KEY=<YOUR ETHERSCAN API KEY>
```

## Security & Key Management

Heavy Helms supports three authentication methods for deployments:

### Hardware Wallet (Recommended for Production)

```bash
forge script <script> --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Private Key Flag (Standard)

```bash
forge script <script> --broadcast --private-key 0xYOUR_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Encrypted Keystore (Automated/CI)

```bash
# One-time setup: create encrypted keystore
cast wallet import deployer --private-key 0xYOUR_PRIVATE_KEY

# Deploy using keystore
forge script <script> --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Deployment Order

GameEngine → EquipmentRequirements → Registries → Fighters → Games

## Step-by-Step

All examples below show the hardware wallet method. Substitute your preferred auth method from above.

### 1. GameEngine

```bash
forge script script/deploy/GameEngineDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. EquipmentRequirements

```bash
forge script script/deploy/EquipmentRequirementsDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 3. PlayerSkinRegistry

```bash
forge script script/deploy/PlayerSkinRegistryDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 4. NameRegistry

```bash
forge script script/deploy/NameRegistryDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 5. Fighters

Deploys multiple contracts in order:
1. PlayerDataCodec helper contract
2. PlayerTickets contract (requires nameRegistry)
3. Player contract (with references to PlayerTickets, PlayerCreation, and PlayerDataCodec)
4. DefaultPlayer and Monster contracts
5. Default skin NFTs and registry setup

```bash
forge script script/deploy/FighterDeploy.s.sol \
  --sig "run(address,address,address,address,address,uint256,bytes32)" \
  <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> \
  <EQUIPMENT_REQUIREMENTS_ADDRESS> <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 6. Unlockable Skin Collection (Optional)

```bash
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS> --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 7. PracticeGame

```bash
forge script script/deploy/PracticeGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 8. DuelGame

```bash
forge script script/deploy/DuelGameDeploy.s.sol \
  --sig "run(address,address,address,address,uint256,bytes32)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 9. GauntletGame

```bash
forge script script/deploy/GauntletGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 10. TournamentGame

```bash
forge script script/deploy/TournamentGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### 11. Chainlink VRF Setup

1. Create a Chainlink VRF subscription on your target network
2. Fund the subscription with LINK tokens or native currency
3. Add the deployed Player + Duel contract as consumers to your subscription
4. Note the VRF Coordinator address, subscription ID, and key hash for deployments

## Usage Scripts

### Create Player

```bash
forge script script/game/player/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE> --broadcast --ledger
```

### Equip Skin

```bash
forge script script/game/player/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID> --broadcast --ledger
```

### Duel Players

```bash
forge script script/game/duel/DuelPlayers.s.sol --sig "run(address,uint32,uint32)" <DUEL_GAME_ADDRESS> <CHALLENGER_ID> <DEFENDER_ID> --broadcast --ledger
```
