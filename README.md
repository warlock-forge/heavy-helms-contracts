# Heavy Helms v2 - Progression

## Deployed Contract Addresses - Base Sepolia

- **GameEngine**: 0xD351cF16cBc8A8732D6E5aB46B3d8b350075567a v1.1
- **EquipmentRequirements**: 0xB7710a3C16f71bD46E174E5806F4274Cbc934837
- **PlayerSkinRegistry**: 0xA308ECAD719A4d8708462318727a6001e6604f10
- **PlayerNameRegistry**: 0x6106E1f3De585b968CEAa4b9f732cCd201aD9811
- **MonsterNameRegistry**: 0xFB1C764754BD6D32DF5FAaf9378e3e969AF57535
- **PlayerDataCodec**: 0x8d620198c96682c11D69CE26600e5FC823d6b763
- **Player**: 0xb19f2D8e0f3Fd0111CA49dc5ae2f656972B6Df4c
- **PlayerTickets**: 0x19AAb75Dc28340a163b3856Ae3Ce698277dfD339
- **DefaultPlayer**: 0xc520795Cb19aE57A1aF91EdDDA637Ea852E262B9
- **Monster**: 0x9c586B69b63c775f05d3c2590c4C2C06D2D6ABE1
- **DefaultPlayerSkinNFT**: 0x2af065B73940Be500A38F4CE63EFE4a6bf3A81D4
- **MonsterSkinNFT**: 0x83d7A13457df1cb1a9c8E29dEE62078a1a7cacf2
- **PracticeGame**: 0xcCC01A2b34aecde9d4a4BDA88D71c117e1A82dC4
- **DuelGame**: 0xEeCF7f20D836744621EB881ABAC7Fb20fF965d5b
- **GauntletGame**: 0xe76A989546397270EaeAF69412F3D703D975BFaE (L1-4)
- **GauntletGame**: 0xd088bb2e9F47cb3175E44E95F0d30Bdd8b3A3307 (L5-9)
- **GauntletGame**: 0xC1773261B5410BF16050621FB18b9de97B63Cb50 (L10)

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

## .env file

```
RPC_URL=<YOUR RPC URL> // Optional - will use forked chain for entropy during testing
ETHERSCAN_API_KEY=<YOUR ETHERSCAN API KEY> // Optional - for contract verification
```

## Security & Key Management

For secure deployments, Heavy Helms supports three authentication methods:

### Hardware Wallet (Recommended for Production)

```bash
# Requires Ledger with Ethereum app and blind signing enabled
forge script <script> --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Private Key Flag (Standard)

```bash
# Pass private key directly via command line
forge script <script> --broadcast --private-key 0xYOUR_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Encrypted Keystore (Automated/CI)

```bash
# One-time setup: create encrypted keystore
cast wallet import deployer --private-key 0xYOUR_PRIVATE_KEY

# Deploy using keystore
forge script <script> --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

## Usage Scripts

- Create Player: _(choose one auth method)_

```bash
# Hardware wallet
forge script script/game/player/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE> --broadcast --ledger

# Private key
forge script script/game/player/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE> --broadcast --private-key 0xYOUR_KEY

# Keystore
forge script script/game/player/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE> --broadcast --keystore ./keystore/deployer
```

- Equip Skin: _(choose one auth method)_

```bash
# Hardware wallet
forge script script/game/player/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID> --broadcast --ledger

# Private key
forge script script/game/player/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID> --broadcast --private-key 0xYOUR_KEY

# Keystore
forge script script/game/player/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID> --broadcast --keystore ./keystore/deployer
```

- Duel Players: _(choose one auth method)_

```bash
# Hardware wallet
forge script script/game/duel/DuelPlayers.s.sol --sig "run(address,uint32,uint32)" <DUEL_GAME_ADDRESS> <CHALLENGER_ID> <DEFENDER_ID> --broadcast --ledger

# Private key
forge script script/game/duel/DuelPlayers.s.sol --sig "run(address,uint32,uint32)" <DUEL_GAME_ADDRESS> <CHALLENGER_ID> <DEFENDER_ID> --broadcast --private-key 0xYOUR_KEY

# Keystore
forge script script/game/duel/DuelPlayers.s.sol --sig "run(address,uint32,uint32)" <DUEL_GAME_ADDRESS> <CHALLENGER_ID> <DEFENDER_ID> --broadcast --keystore ./keystore/deployer
```

## Installation

1. Clone the repository:

```bash
git clone https://github.com/warlock-forge/heavy-helms-contracts.git
cd heavy-helms-contracts
```

2. Install dependencies:

```bash
forge install --no-git foundry-rs/forge-std@1eea5ba bokkypoobah/BokkyPooBahsDateTimeLibrary@1dc26f9 vectorized/solady@v0.1.24 smartcontractkit/chainlink-evm@v0.3.2 OpenZeppelin/openzeppelin-contracts@v4.9.6
```

3. Deploy GameEngine contract _(choose auth method)_

```bash
# Hardware wallet (recommended for production)
forge script script/deploy/GameEngineDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/GameEngineDeploy.s.sol --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/GameEngineDeploy.s.sol --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

4. Deploy EquipmentRequirements contract _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/EquipmentRequirementsDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/EquipmentRequirementsDeploy.s.sol --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/EquipmentRequirementsDeploy.s.sol --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

5. Deploy PlayerSkinRegistry: _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/PlayerSkinRegistryDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/PlayerSkinRegistryDeploy.s.sol --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/PlayerSkinRegistryDeploy.s.sol --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

6. Deploy NameRegistry: _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/NameRegistryDeploy.s.sol --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/NameRegistryDeploy.s.sol --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/NameRegistryDeploy.s.sol --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

7. Deploy Fighters (includes PlayerTickets and helper contracts): _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/FighterDeploy.s.sol \
  --sig "run(address,address,address,address,address,uint256,bytes32)" \
  <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> \
  <EQUIPMENT_REQUIREMENTS_ADDRESS> <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/FighterDeploy.s.sol \
  --sig "run(address,address,address,address,address,uint256,bytes32)" \
  <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> \
  <EQUIPMENT_REQUIREMENTS_ADDRESS> <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/FighterDeploy.s.sol \
  --sig "run(address,address,address,address,address,uint256,bytes32)" \
  <SKIN_REGISTRY_ADDRESS> <PLAYER_NAME_REGISTRY_ADDRESS> <MONSTER_NAME_REGISTRY_ADDRESS> \
  <EQUIPMENT_REQUIREMENTS_ADDRESS> <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

**Note:** The FighterDeploy script now deploys multiple contracts in this order:

1. PlayerDataCodec helper contract
2. PlayerTickets contract (requires nameRegistry)
3. Player contract (with references to PlayerTickets, PlayerCreation, and PlayerDataCodec)
4. DefaultPlayer and Monster contracts
5. Default skin NFTs and registry setup

All contracts are deployed automatically within the FighterDeploy script - no separate deployment needed.

8. Deploy Unlockable Skin Collection (Optional): _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS> --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS> --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/UnlockableSkinDeploy.s.sol --sig "run(address)" <SKIN_REGISTRY_ADDRESS> --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

9. Deploy PracticeGame _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/PracticeGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/PracticeGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS> \
  --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/PracticeGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <MONSTER_CONTRACT_ADDRESS> \
  --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

10. Deploy DuelGame _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/DuelGameDeploy.s.sol \
  --sig "run(address,address,address,address,uint256,bytes32)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/DuelGameDeploy.s.sol \
  --sig "run(address,address,address,address,uint256,bytes32)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/DuelGameDeploy.s.sol \
  --sig "run(address,address,address,address,uint256,bytes32)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  <VRF_COORDINATOR> <SUBSCRIPTION_ID> <KEY_HASH> \
  --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

11. Deploy GauntletGame _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/GauntletGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/GauntletGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/GauntletGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

12. Deploy TournamentGame _(choose auth method)_

```bash
# Hardware wallet (recommended)
forge script script/deploy/TournamentGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --ledger --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Private key
forge script script/deploy/TournamentGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --private-key 0xYOUR_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Keystore
forge script script/deploy/TournamentGameDeploy.s.sol \
  --sig "run(address,address,address,address)" \
  <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS> <DEFAULT_PLAYER_CONTRACT_ADDRESS> <PLAYER_TICKETS_ADDRESS> \
  --broadcast --keystore ./keystore/deployer --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

13. Setup Chainlink VRF

```bash
# 1. Create a Chainlink VRF subscription on your target network
# 2. Fund the subscription with LINK tokens or native currency
# 3. Add the deployed Player + Duel contract as consumers to your subscription
# 4. Note the VRF Coordinator address, subscription ID, and key hash for deployments
```

### Test

```shell
$ forge test
```
