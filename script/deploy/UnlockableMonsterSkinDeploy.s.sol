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
        PlayerSkinNFT unlockableSkin = new PlayerSkinNFT("Player Monster Skin Pantheon", "HHPANTHEON", 0);

        // Register unlockable skin collection
        uint32 unlockableSkinIndex = skinRegistry.registerSkin(address(unlockableSkin));

        // Set the unlock NFT address for this collection
        skinRegistry.setRequiredNFT(unlockableSkinIndex, 0x842f92108c94bF8362dEF5910eFB318E302f7895);

        // Set the IPFS base URI
        unlockableSkin.setBaseURI("ipfs://bafybeicqhrdh6hpit4bq7stahzwjqujlv3rj4qzcm3eovx36s352k6i6nu/");

        // IMPORTANT: Set verified BEFORE minting so subgraph indexes mints correctly
        skinRegistry.setSkinVerification(unlockableSkinIndex, true);

        console2.log("\n=== Minting Unlockable Characters ===");

        // Mint Medusa (ID 1)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            3, // WEAPON_GREATSWORD
            1 // ARMOR_LEATHER
        );

        // Mint Anubis (ID 2)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            5, // WEAPON_QUARTERSTAFF
            0 // ARMOR_CLOTH
        );

        // Mint Devil (ID 3)
        unlockableSkin.mintSkin(
            address(unlockableSkin),
            26, // WEAPON_TRIDENT
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
