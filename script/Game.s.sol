// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";
import {GameStats} from "../src/GameStats.sol";
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
        vm.startBroadcast();

        // 1. Deploy core contracts in correct order
        GameStats gameStats = new GameStats();
        PlayerSkinRegistry skinRegistry = new PlayerSkinRegistry();
        PlayerNameRegistry nameRegistry = new PlayerNameRegistry();
        Player playerContract = new Player(address(skinRegistry), address(nameRegistry), address(gameStats));
        GameEngine gameEngine = new GameEngine();
        Game game = new Game(address(gameEngine), address(playerContract), address(gameStats), address(skinRegistry));

        // 2. Deploy and setup DefaultPlayerSkinNFT
        DefaultPlayerSkinNFT defaultSkin = new DefaultPlayerSkinNFT();

        // Register default skin collection
        uint32 skinIndex = skinRegistry.registerSkin(address(defaultSkin));
        skinRegistry.setDefaultSkinRegistryId(skinIndex);

        // 3. Mint initial default characters
        // Balanced Character
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 1);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID);

        // Greatsword Offensive Character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getGreatswordUser(skinIndex, 2);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID);

        // Defensive Character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getDefensiveTestWarrior(skinIndex, 3);

        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID);

        // Log deployed addresses
        console2.log("Deployed Addresses:");
        console2.log("GameStats:", address(gameStats));
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
