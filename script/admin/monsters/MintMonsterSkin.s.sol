// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {MonsterSkinNFT} from "../../../src/nft/skins/MonsterSkinNFT.sol";

contract MintMonsterSkin is Script {
    function setUp() public {}

    function run(address monsterSkinAddr, uint8 weapon, uint8 armor, string memory ipfsCid, uint16 skinTokenId) public {
        // Get values from .env
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        MonsterSkinNFT monsterSkin = MonsterSkinNFT(monsterSkinAddr);

        uint16 tokenId = monsterSkin.mintMonsterSkin(weapon, armor, ipfsCid, skinTokenId);

        console2.log("Minted Monster Skin with Token ID:", tokenId);
        console2.log("Weapon:", weapon);
        console2.log("Armor:", armor);
        console2.log("IPFS CID:", ipfsCid);

        vm.stopBroadcast();
    }
}
