// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {PlayerSkinRegistry} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {PlayerSkinNFT} from "../../src/nft/skins/PlayerSkinNFT.sol";

contract UnlockableSkinDeployScript is Script {
    function run(address skinRegistryAddress) public {
        string memory rpcUrl = vm.envString("RPC_URL");

        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        PlayerSkinRegistry skinRegistry = PlayerSkinRegistry(payable(skinRegistryAddress));

        // Deploy unlockable skin collection
        PlayerSkinNFT unlockableSkin = new PlayerSkinNFT("Player Monster Skin Goblin", "HHGOBLIN", 0);

        // Register unlockable skin collection
        uint32 unlockableSkinIndex = skinRegistry.registerSkin(address(unlockableSkin));

        // Set the unlock NFT address for this collection
        skinRegistry.setRequiredNFT(unlockableSkinIndex, 0x0c493355A1880812470ADBCF9C2Ae2ecA8082e08);

        // Set the IPFS base URI
        unlockableSkin.setBaseURI("ipfs://bafybeiaubu5krbuyexznxwjp6rov2xmvhebctsz26hm5ghr525gxwpuxue/");

        // IMPORTANT: Set verified BEFORE minting so subgraph indexes mints correctly
        skinRegistry.setSkinVerification(unlockableSkinIndex, true);

        console2.log("\n=== Minting Unlockable Characters ===");

        // Mint Clubs (ID 1)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            18, // WEAPON_DUAL_CLUBS
            1 // ARMOR_LEATHER
        );

        // Mint Swords (ID 2)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            19, // WEAPON_ARMING_SWORD_SHORTSWORD
            1 // ARMOR_LEATHER
        );

        // Mint Maul (ID 3)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            25, // WEAPON_MAUL
            1 // ARMOR_LEATHER
        );

        // Disable minting after we're done
        //unlockableSkin.setMintingEnabled(false);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("UnlockablePlayerSkinNFT:", address(unlockableSkin));
        console2.log("Unlockable Skin Registry Index:", unlockableSkinIndex);

        vm.stopBroadcast();
    }
}
