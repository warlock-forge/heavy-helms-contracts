// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../src/Player.sol";
import {DefaultPlayerSkinNFT} from "../../src/DefaultPlayerSkinNFT.sol";
import {DefaultPlayerLibrary} from "../../src/lib/DefaultPlayerLibrary.sol";
import {IGameDefinitions} from "../../src/interfaces/IGameDefinitions.sol";
import {IPlayer} from "../../src/interfaces/IPlayer.sol";
import {PlayerSkinRegistry} from "../../src/PlayerSkinRegistry.sol";

contract PlayerDeployScript is Script {
    function setUp() public {}

    function run(address skinRegistryAddr, address nameRegistryAddr, address equipmentStatsAddr) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");
        address operator = vm.envAddress("GELATO_VRF_OPERATOR");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Player contract with Gelato VRF operator
        Player playerContract = new Player(skinRegistryAddr, nameRegistryAddr, operator);

        // 2. Deploy and setup DefaultPlayerSkinNFT
        DefaultPlayerSkinNFT defaultSkin = new DefaultPlayerSkinNFT();

        // Register default skin collection and set it as default
        uint32 skinIndex = PlayerSkinRegistry(payable(skinRegistryAddr)).registerSkin(address(defaultSkin));
        PlayerSkinRegistry(payable(skinRegistryAddr)).setDefaultSkinRegistryId(skinIndex);
        PlayerSkinRegistry(payable(skinRegistryAddr)).setDefaultCollection(skinIndex, true); // Mark as default collection

        // 3. Mint initial default characters
        console2.log("\n=== Minting Default Characters ===");

        // Balanced Warrior (ID 1)
        (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
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

        // Rapier and Shield User (ID 4)
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, 4);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 4);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("Player:", address(playerContract));
        console2.log("DefaultPlayerSkinNFT:", address(defaultSkin));
        console2.log("Default Skin Registry Index:", skinIndex);

        vm.stopBroadcast();
    }
}
