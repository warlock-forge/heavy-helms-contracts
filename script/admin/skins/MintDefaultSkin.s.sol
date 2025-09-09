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
    function run(address defaultSkinAddr, address defaultPlayerAddr, DefaultPlayerLibrary.CharacterType characterType)
        public
    {
        require(defaultSkinAddr != address(0), "DefaultSkin address cannot be zero");
        require(defaultPlayerAddr != address(0), "DefaultPlayer address cannot be zero");

        // Get private key from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        DefaultPlayerSkinNFT defaultSkin = DefaultPlayerSkinNFT(defaultSkinAddr);
        DefaultPlayer defaultPlayer = DefaultPlayer(defaultPlayerAddr);

        uint32 defaultSkinIndex = 0; // Default collection is always index 0
        uint16 tokenId = uint16(characterType) + 1;

        // Create the default character using the library's public interface
        DefaultPlayerLibrary.createDefaultCharacter(
            defaultSkin, defaultPlayer, defaultSkinIndex, tokenId, characterType
        );

        console2.log("Created default character type:", uint8(characterType));
        console2.log("Token ID:", tokenId);

        vm.stopBroadcast();
    }
}
