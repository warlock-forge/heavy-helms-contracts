// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import {GameEngine} from "../src/GameEngine.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/lib/DefaultPlayerLibrary.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import "../src/interfaces/IPlayer.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";

contract GameScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy core contracts in correct order
        PlayerEquipmentStats equipmentStats = new PlayerEquipmentStats();
        PlayerSkinRegistry skinRegistry = new PlayerSkinRegistry();
        PlayerNameRegistry nameRegistry = new PlayerNameRegistry();
        Player playerContract = new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats));
        GameEngine gameEngine = new GameEngine();
        Game game = new Game(address(gameEngine), address(playerContract));

        // 2. Deploy and setup DefaultPlayerSkinNFT
        DefaultPlayerSkinNFT defaultSkin = new DefaultPlayerSkinNFT();

        // Register default skin collection and set it as default
        uint32 skinIndex = skinRegistry.registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true); // Mark as default collection

        // 3. Mint initial default characters
        console2.log("\n=== Minting Default Characters ===");

        // Balanced Warrior (ID 1)
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 1);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 1);

        // Sword and Shield User (ID 2)
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getBalancedWarrior(skinIndex, 2);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 2);

        // Greatsword User (ID 3)
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getGreatswordUser(skinIndex, 3);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 3);

        // Log deployed addresses
        console2.log("Deployed Addresses:");
        console2.log("PlayerEquipmentStats:", address(equipmentStats));
        console2.log("PlayerSkinRegistry:", address(skinRegistry));
        console2.log("PlayerNameRegistry:", address(nameRegistry));
        console2.log("Player:", address(playerContract));
        console2.log("GameEngine:", address(gameEngine));
        console2.log("Game:", address(game));
        console2.log("DefaultPlayerSkinNFT:", address(defaultSkin));
        console2.log("Default Skin Registry Index:", skinIndex);

        vm.stopBroadcast();
    }
}
