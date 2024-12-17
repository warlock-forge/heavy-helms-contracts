# Heavy Helms

## Features

- Modular contract system that enables new games modes to be added in the future without losing any player state or migrating any contracts 
- Decentralized game design allows for creators to build their own custom game modes - no permission needed (unless you want to modify player state 🛡️). NFT makers can even create and sell custom skins that can be equipped by players using the Player contract SkinRegistry system
- Permissioned whitelist system unlocks the ability for game contracts to change player state (increment record, set player status to dead 🧟 <- opt in hardcore game mode, etc.) if approved by Player contract owner
- Players can create their own characters and customize them by collecting unique skins - or equip one from our default collection. The skin you have equipped determines your Weapon, Armor, and Combat Stance - so choose wisely
- No pay to win! All players have the same amount of total attribute points - they are just distributed differently. Skins do not provide any comptetitive advantage as Weapon and Armor choices are not locked behind expensive skins
- Fully onchain versioned game engine that handles all game logic - including combat mechanics such as initiative, hit chance, blocks and counters, etc. Also accounts for player attributes in damage calculations, Weapon and Armor modifiers, etc.
- The game engine is a view that returns an encoded byte string which contains the results of all of the rounds of combat - each round result is encoded in to 8 bytes. For example the results of a 10 round fight take up only 80 bytes (well 87 bytes if you include the 7 byte prefix that contains the winning player ID, game version, and win condition 🤓)
- The Practice game mode allows us to leverage the fact that game engine is a view. We use some blockchain derived pseudo randomness to simulate a fight completely gas free. Our game client gets those combat bytes, decodes them, and shows the user a fun fight. Of course we do not modify player state - this is practice after all
- The Duel mode takes Practice mode to the next level - even allowing players to wager on the result if they so choose - using a unique initiate/accept challenge flow. This game mode uses VRF to ensure fairness and cleverly escrows any wager amounts until the duel is complete
- That Duel now lives forever on the blokchain in the emit'ed event logs. Since we store all of the fight results in a bytes string (including game engine version) the game client can display to the user the exact state of that fight (inclduing what skin the players had equipped, etc.).

## Deployed Contract Addresses - Shape Mainnet

- Player: 0xA909501cEe754bfE0F00DF7c21653957caaAdF03
- GameEngine: 0xEF804F79014F937973f37Bb80D5dc9Bf16543e1e
- PracticeGame: 0x84c0b41D8792afB4E333E8E849cC9B4ce8CCA1cF
- DuelGame: 0xF2b9189e0Aa4C495220F201459e97D33D637f700
- PlayerEquipmentStats: 0x1c132aeFe568B7d5CAaC0FC76203e94dbFD0e85D
- PlayerSkinRegistry: 0x229675571F5F268Df593990dB6fbd2bc29FA9131
- PlayerNameRegistry: 0xCFDBa63076Ef774B730AeccC5FEf41addD10726a
- DefaultPlayerSkinNFT: 0xfbc1A2E161Bb516165152C6Ec3F7e046f5366834
- UnlockablePlayerSkinNFT: 0x581D3A98dD2Ce08D087C3eE944ad8118CAD07eA1 (Need a Shapecraft Key 0x05aA491820662b131d285757E5DA4b74BD0F0e5F to use this skin collection)

## Noteworty Transactions
- First OnChain Duel:
https://shapescan.xyz/tx/0x18c91a5e670581d37c8a565f98fbae40b443fed8f4a588692cf243dfe37b4c33
- First Player Created (using VRF): https://shapescan.xyz/tx/0x1ae7d90088b34fa61156357755fed36750da79681c81017449b3ae3731039537
- Player 1 owned by address 0xA069EcA6dEfc3f9E13e6C9f75629beA64655b729 <-- Owns Shapecraft Key NFT Equiping locked skin collection: 
https://shapescan.xyz/tx/0x32b5c1e6e9a3acb2179158b1fee3e385fa55f944c00f99b4e331b853117ab87b

## Usage Scripts

- Create Player: *(add --broadcast to send tx)*
```bash
forge script script/CreatePlayer.s.sol:CreatePlayerScript --sig "run(address,bool)" <PLAYER_CONTRACT_ADDRESS> <IS_FEMALE>
```
- Equip Skin: *(add --broadcast to send tx)*
```bash
forge script script/EquipSkin.s.sol --sig "run(address,uint32,uint32,uint16)" <PLAYER_CONTRACT_ADDRESS> <PLAYER_ID> <SKIN_INDEX> <TOKEN_ID>
```

- Duel Players (both should be owned by PK): *(add --broadcast to send tx)*
```bash
forge script script/DuelPlayers.s.sol --sig "run(address,uint32,uint32)" <DUEL_GAME_ADDRESS> <CHALLENGER_ID> <DEFENDER_ID>
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

## .env file
```
RPC_URL=<YOUR RPC URL> // Optional - will use forked chain for entropy during testing
PK=<YOUR PRIVATE KEY> // Only needed for deployment + scripts
GELATO_VRF_OPERATOR=<YOUR GELATO VRF OPERATOR> // Only needed for deployment
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
3. Deploy Player + helper contracts: *(add --broadcast to send tx)*
```bash
forge script script/PlayerDeploy.s.sol
```
4. Deploy GameEngine contract *(add --broadcast to send tx)*
```bash
forge script script/GameEngineDeploy.s.sol
```
5. Deploy PracticeGame
```bash
forge script script/PracticeGameDeploy.s.sol --sig "run(address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS>
```
6. Deploy DuelGame
```bash
forge script script/DuelGameDeploy.s.sol --sig "run(address,address)" <GAME_ENGINE_ADDRESS> <PLAYER_CONTRACT_ADDRESS>
```
7. Setup VRF
```bash
Use Gelato dashboard to add VRF tasks for Player + Duel Game contracts
```

### Test

```shell
$ forge test
```

