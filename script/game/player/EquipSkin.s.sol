// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../../src/fighters/Player.sol";
import {PlayerSkinRegistry} from "../../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {IPlayer} from "../../../src/interfaces/fighters/IPlayer.sol";

contract EquipSkinScript is Script {
    function setUp() public {}

    function run(address playerContractAddr, uint32 playerId, uint32 skinIndex, uint16 tokenId) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        // Get the deployed Player contract
        Player player = Player(playerContractAddr);

        // Get the skin registry
        // PlayerSkinRegistry skinRegistry = PlayerSkinRegistry(payable(player.skinRegistry()));

        // Equip the skin
        player.equipSkin(playerId, skinIndex, tokenId);
        console2.log("Equipped skin to player", playerId);
        console2.log("Skin Index:", skinIndex);
        console2.log("Token ID:", tokenId);

        // Get and display player stats
        IPlayer.PlayerStats memory stats = player.getPlayer(playerId);
        console2.log("\nUpdated Player Stats:");
        console2.log("Strength:", stats.attributes.strength);
        console2.log("Constitution:", stats.attributes.constitution);
        console2.log("Size:", stats.attributes.size);
        console2.log("Agility:", stats.attributes.agility);
        console2.log("Stamina:", stats.attributes.stamina);
        console2.log("Luck:", stats.attributes.luck);
        console2.log("Skin Index:", stats.skin.skinIndex);
        console2.log("Skin Token ID:", stats.skin.skinTokenId);

        vm.stopBroadcast();
    }
}
