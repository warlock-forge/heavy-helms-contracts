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

## Noteworty Transactions
- First OnChain Duel (using VRF):
https://shapescan.xyz/tx/0x18c91a5e670581d37c8a565f98fbae40b443fed8f4a588692cf243dfe37b4c33
- First Player Created (using VRF): https://shapescan.xyz/tx/0x1ae7d90088b34fa61156357755fed36750da79681c81017449b3ae3731039537
- Player 1 owned by address 0xA069EcA6dEfc3f9E13e6C9f75629beA64655b729 <-- Owns Shapecraft Key NFT Equiping locked skin collection: 
https://shapescan.xyz/tx/0x32b5c1e6e9a3acb2179158b1fee3e385fa55f944c00f99b4e331b853117ab87b

## Contract FAQs

**Q: What is a player?**  
A: A Player in the context of Heavy Helms is probably best described by the struct defined in the IPlayer interface:
```solidity
struct PlayerStats {
    uint8 strength;
    uint8 constitution;
    uint8 size;
    uint8 agility;
    uint8 stamina;
    uint8 luck;
    uint32 skinIndex;
    uint16 skinTokenId;
    uint32 firstNameIndex;
    uint32 surnameIndex;
    uint32 wins;
    uint32 losses;
    uint32 kills;
}
```
Lets break this down a little bit: We have 6 attributes (str, con, size, agi, stam, luck), name and skin references, in addition to record. These PlayerStats structs are stored in state on the Player contract and mapped to an address.
```solidity
// Player state tracking
mapping(uint32 => IPlayer.PlayerStats) private _players;
mapping(uint32 => address) private _playerOwners;
```
**Q: Is a player an NFT?**  
A: No. This is by design. Players are not allowed to be transferred  to a different address. Customization via NFTs is done through skins that are equipped by players.

**Q: What is a skin?**  
A: A skin is a normal ERC721 NFT that implements the IPlayerSkinNFT. The PlayerSkinNFT contract not only keeps track of standard NFT metadata (including a new spritesheet_image field) but also stores the "strategy" settings of this skin in state:
```solidity
    enum WeaponType {
        SwordAndShield,
        MaceAndShield,
        Greatsword,
        Battleaxe,
        Quarterstaff,
        Spear,
        RapierAndShield
    }
    enum ArmorType {
        Plate,
        Chain,
        Leather,
        Cloth
    }
    enum FightingStance {
        Defensive,
        Balanced,
        Offensive
    }
```

**Q: Skins include a strategy too?**  
A: Yes. In Heavy Helms, not only does the skin you equip change how the player appears in game (the client loads spritesheet via IPFS) but also what weapon and armor they have equipped along with their fighting stance. 

**Q: How do I get skins?**  
A: There are three different types of skins in the game:
1. Default Skins - This collection of skins can be equipped by anyone. We intend to have a wide variety of skins in this collection so no strategies are locked behind a paywall. These are important as they allow users to create a new player and equip them with a skin that fits their desired strategy without having to invest in any NFTs.
2. Unlockable Skins - This is another type of skin collection that requires a specific NFT (like a Shapecraft Key) to unlock. These collections can be used to collaborate with other projects to incentivize NFT ownership.
3. NFT Skins - If a user owns a token from a verified IPlayerSkinNFT collection (See PlayerSkinRegistry), they can equip that NFT skin on their player. This allows for any NFT artist to create and sell their own skins that can be equipped by players. Here is the integration guide for NFT artists (*WIP - check PlayerSkinNFT.sol in examples*)

**Q: So what do player attributes + skins do?**  
A: The Player contract uses the 6 player attributes to calculate some base stats:
```solidity
    struct CalculatedStats {
        uint16 maxHealth;
        uint16 damageModifier;
        uint16 hitChance;
        uint16 blockChance;
        uint16 dodgeChance;
        uint16 maxEndurance;
        uint16 critChance;
        uint16 initiative;
        uint16 counterChance;
        uint16 critMultiplier;
        uint16 parryChance;
    }
```
The onchain game engine (GameEngine.sol) uses these stats combined with strategy specific modifiers to determine the outcome of each round of combat. Each strategy element has a strength and weakness (ie Plate is vuleraneble to blunt weapons but quite effective against slashing and piercing) as well as attribute requirements. These are defined in the PlayerEquipmentStats contract (PlayerEquipmentStats.sol).

**Q: So what can I do with a player?**  
A: Good question and I am glad you are still following along! We currently have 2 distinct game modes:
- Practice Game: This is the simplest of game modes and doesn't actually make any state changes(record does not increase, etc.). The beauty of this is that since these are all views - we can not only run these for free but we can allow users to experience this game mode without even needing a wallet or logging in. We pass the 2 player IDs we want to fight to the `play()` method and send the returned combat bytes to the game client. This game mode uses a pseuso-random number based on block entropy - so a new fight outcome happens every block. Since we do not modify state however, once the fight is over the results are "lost".
- Duel Game: This mode allows a player to challenge another player to a duel and records are on the line. The winner will pickup a win on their record and the loser takes an L... this changes state for that player. This game mode uses VRF and also stores the match results in the event logs (including what skins players had equipped, etc.) of the transaction. This allows this fight to be shared and viewed by anyone simply by providing the transaction hash to the game client. This allows anyone to interact with and watch other fights via leaderboards, etc. to stay engaged in the community. Players who so wish can place a wager on the Duel and the contract esnures that the wager amount is escrowed until the fight is resolved.

**Q: Will new game modes be added?**  
A: Yes! The player contract was designed with a modular permission system that allows the contract owner to grant permissions to (future) game contracts that allow them to modify player state.
```solidity
    struct GamePermissions {
        bool record; // Can modify game records
        bool retire; // Can retire players
        bool name; // Can change names
        bool attributes; // Can modify attributes
    }
```
We are currently working on a tournament game mode that will allow players to compete for prizes including exclusive skins as well as cool player specific rewards such as one time name change, attribute adjustment, etc.

**Q: What if the onchain game engine is unbalanced/broken?**  
A: We have taken a modular approach to the game engine as well. Each game mode can use either a completely different game engine (GameEngine.sol) or take advanatge of the built in versioning system. We track a version number in GameEngine.sol and have a helper method to split major and minor versions from our uint16 (giving us a total of 256 major and 256 minor versions):
```solidity
uint16 public constant override version = 1;
function decodeVersion(uint16 _version) public pure returns (uint8 major, uint8 minor) {
    major = uint8(_version >> 8); // Get upper 8 bits
    minor = uint8(_version & 0xFF); // Get lower 8 bits
}
```
This allows us to upgrade our game engine while keeping our game client in sync. Since the game engine version is encoded in to the combat bytes we can let the game client handle the expected combat bytes based on the version of the game engine.

**Q: Can I use my players in other games?**  
A: Yes! Not only can other creators tweak the game engine but they can even create entirely new game modes! Your player spritesheet and attributes in other worlds!

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

