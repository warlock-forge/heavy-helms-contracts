// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../src/Player.sol";
import {PlayerEquipmentStats} from "../src/PlayerEquipmentStats.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../src/PlayerNameRegistry.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import {DefaultPlayerLibrary} from "../src/lib/DefaultPlayerLibrary.sol";
import {PlayerSkinNFT} from "../src/examples/PlayerSkinNFT.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import "../src/interfaces/IPlayer.sol";

contract PlayerDeployScript is Script {
    function setUp() public {}

    function run() public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");
        address operator = vm.envAddress("GELATO_VRF_OPERATOR");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy core contracts in correct order
        PlayerEquipmentStats equipmentStats = new PlayerEquipmentStats();
        PlayerSkinRegistry skinRegistry = new PlayerSkinRegistry();
        PlayerNameRegistry nameRegistry = new PlayerNameRegistry();

        // Deploy Player contract with Gelato VRF operator
        Player playerContract =
            new Player(address(skinRegistry), address(nameRegistry), address(equipmentStats), operator);

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

        // Deploy unlockable skin collection
        PlayerSkinNFT unlockableSkin = new PlayerSkinNFT("Shapecraft Key Collection", "SKHHSKIN", 0);

        // Register unlockable skin collection
        uint32 unlockableSkinIndex = skinRegistry.registerSkin(address(unlockableSkin));

        // Set the unlock NFT address for this collection
        skinRegistry.setRequiredNFT(unlockableSkinIndex, 0x05aA491820662b131d285757E5DA4b74BD0F0e5F);

        // Set the IPFS base URI
        unlockableSkin.setBaseURI("ipfs://QmXeA9ARshQiRWkt6cffcrr2EN5jjofhBi5GQaVmVEKJSX/");

        // Enable minting
        unlockableSkin.setMintingEnabled(true);

        console2.log("\n=== Minting Unlockable Characters ===");

        // Mint Quarterstaff Mystic (ID 1)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            IPlayerSkinNFT.WeaponType.Quarterstaff,
            IPlayerSkinNFT.ArmorType.Cloth,
            IPlayerSkinNFT.FightingStance.Offensive
        );

        // Mint Mace Guardian (ID 2)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            IPlayerSkinNFT.WeaponType.MaceAndShield,
            IPlayerSkinNFT.ArmorType.Chain,
            IPlayerSkinNFT.FightingStance.Defensive
        );

        // Mint Battle Master (ID 3)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            IPlayerSkinNFT.WeaponType.Battleaxe,
            IPlayerSkinNFT.ArmorType.Leather,
            IPlayerSkinNFT.FightingStance.Offensive
        );

        // Set the collection as verified
        skinRegistry.setSkinVerification(unlockableSkinIndex, true);

        // Disable minting after we're done
        unlockableSkin.setMintingEnabled(false);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("PlayerEquipmentStats:", address(equipmentStats));
        console2.log("PlayerSkinRegistry:", address(skinRegistry));
        console2.log("PlayerNameRegistry:", address(nameRegistry));
        console2.log("Player:", address(playerContract));
        console2.log("DefaultPlayerSkinNFT:", address(defaultSkin));
        console2.log("Default Skin Registry Index:", skinIndex);
        console2.log("UnlockablePlayerSkinNFT:", address(unlockableSkin));
        console2.log("Unlockable Skin Registry Index:", unlockableSkinIndex);

        vm.stopBroadcast();
    }
}
