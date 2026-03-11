# Deployment Script Patterns

Follow these patterns EXACTLY when writing new deployment scripts.

**Note:** General Solidity style (file header, naming conventions, NatSpec) is covered by `rules/code-style.md`. This file covers deployment-specific patterns only.

## Script Location

All deploy scripts go in: `script/deploy/{ContractName}Deploy.s.sol`

## Import Pattern

```solidity
// Always import Script and console2 from forge-std
import {Script, console2} from "forge-std/Script.sol";

// Contract imports use relative paths from script/deploy/
import {ContractName} from "../../src/path/to/ContractName.sol";

// Interface imports
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
```

## Contract Structure

```solidity
contract {ContractName}DeployScript is Script {
    function setUp() public {}

    function run(
        address param1,
        address payable param2,  // Use payable if needed
        uint256 numericParam,
        bytes32 hashParam
    ) public {
        // 1. Validate addresses
        require(param1 != address(0), "Param1 address cannot be zero");
        require(param2 != address(0), "Param2 address cannot be zero");

        // 2. Start broadcast (target chain set via --rpc-url on CLI)
        vm.startBroadcast();

        // 3. Deploy and configure
        // ... deployment logic ...

        // 4. Log results (BEFORE stopBroadcast)
        console2.log("\n=== Deployed Addresses ===");
        console2.log("ContractName:", address(contract));

        // 5. Stop broadcast
        vm.stopBroadcast();
    }
}
```

## No-Params Deploy (Simple)

For contracts with no constructor args:

```solidity
function run() public {
    vm.startBroadcast();

    ContractName instance = new ContractName();

    console2.log("\n=== Deployed Addresses ===");
    console2.log("ContractName:", address(instance));

    vm.stopBroadcast();
}
```

## Game Contract Permissions

Game contracts need whitelisting in Player and PlayerTickets:

```solidity
// Whitelist in Player contract
Player playerContract = Player(playerAddr);
IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
    record: true,
    retire: false,      // true only for death-enabled games
    immortal: false,    // true for practice games
    experience: true
});
playerContract.setGameContractPermission(address(gameContract), perms);

// Whitelist in PlayerTickets contract
PlayerTickets playerTicketsContract = PlayerTickets(playerTicketsAddr);
PlayerTickets.GamePermissions memory ticketPerms = PlayerTickets.GamePermissions({
    playerCreation: true,
    playerSlots: true,
    nameChanges: true,
    weaponSpecialization: true,
    armorSpecialization: true,
    duels: true,
    dailyResets: true,
    attributeSwaps: true
});
playerTicketsContract.setGameContractPermission(address(gameContract), ticketPerms);
```

## VRF-Enabled Contracts

Contracts using Chainlink VRF need these params:

```solidity
function run(
    // ... other params ...
    address vrfCoordinator,
    uint256 subscriptionId,
    bytes32 keyHash
) public {
    // Pass to constructor
    VRFContract instance = new VRFContract(
        // ... other args ...
        vrfCoordinator,
        subscriptionId,
        keyHash
    );
}
```

## Helper Functions for Complex Deploys

For deploying multiple instances (like GauntletGame brackets):

```solidity
function deployInstance(
    address param1,
    address param2,
    SomeEnum variant
) internal {
    Contract instance = new Contract(param1, param2, variant);

    // Setup permissions...

    console2.log("\n=== Deployed Instance ===");
    console2.log("Address:", address(instance));
    console2.log("Variant:", uint8(variant));
}
```

## Console Logging Format

```solidity
// Section headers
console2.log("\n=== Section Name ===");

// Address output
console2.log("ContractName:", address(contract));

// Status messages
console2.log("Contract whitelisted in Player contract");

// Numeric values
console2.log("Skin Registry Index:", skinIndex);
console2.log("Level Bracket:", uint8(bracket));
```

## Hardcoded Values Reference

IPFS CIDs used in this project (content-addressed, stable):
- Fungible metadata: `bafybeib2pydnkibnj5o3udxg2grmh4dt2tztcecccka4rxia5xumqpemjm`
- Name change image: `bafybeibgu5ach7brer6jcjqcgtacxn2ltmgxwencxmcmlf3jt5mmwhxrje`
- Base URI prefix: `ipfs://bafybeidyvui7z7e3c35eymdthhkbnn7etnrrukpfaakzramu6vihvpoexe/`

## Common Import Paths

```solidity
// Game contracts
import {PracticeGame} from "../../src/game/modes/PracticeGame.sol";
import {GauntletGame} from "../../src/game/modes/GauntletGame.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {TournamentGame} from "../../src/game/modes/TournamentGame.sol";
import {MonsterBattleGame} from "../../src/game/modes/MonsterBattleGame.sol";

// Fighter contracts
import {Player} from "../../src/fighters/Player.sol";
import {DefaultPlayer} from "../../src/fighters/DefaultPlayer.sol";
import {Monster} from "../../src/fighters/Monster.sol";

// Interfaces
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";
import {IMonster} from "../../src/interfaces/fighters/IMonster.sol";

// NFT contracts
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

// Registries
import {PlayerSkinRegistry} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
```
