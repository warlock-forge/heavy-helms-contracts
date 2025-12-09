// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {DefaultPlayerSkinNFT} from "../../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import {DefaultPlayerLibrary} from "../../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {DefaultPlayer} from "../../../src/fighters/DefaultPlayer.sol";

contract MintDefaultSkinScript is Script {
    function run(address defaultSkinAddr, address defaultPlayerAddr, uint16 characterId) public {
        require(defaultSkinAddr != address(0), "DefaultSkin address cannot be zero");
        require(defaultPlayerAddr != address(0), "DefaultPlayer address cannot be zero");
        require(characterId >= 1 && characterId <= DefaultPlayerLibrary.CHARACTER_COUNT, "Invalid character ID");

        // Get private key from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast();

        DefaultPlayerSkinNFT defaultSkin = DefaultPlayerSkinNFT(defaultSkinAddr);
        DefaultPlayer defaultPlayer = DefaultPlayer(defaultPlayerAddr);

        uint32 defaultSkinIndex = 0; // Default collection is always index 0

        // Create the default character using the library's public interface
        DefaultPlayerLibrary.createDefaultCharacter(defaultSkin, defaultPlayer, defaultSkinIndex, characterId);

        console2.log("Created default character ID:", characterId);

        vm.stopBroadcast();
    }
}
