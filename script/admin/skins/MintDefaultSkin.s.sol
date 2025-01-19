// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DefaultPlayerSkinNFT} from "../../../src/DefaultPlayerSkinNFT.sol";
import {DefaultPlayerLibrary} from "../../../src/lib/DefaultPlayerLibrary.sol";
import {PlayerSkinRegistry} from "../../../src/PlayerSkinRegistry.sol";
import {IGameDefinitions} from "../../../src/interfaces/IGameDefinitions.sol";
import {IPlayer} from "../../../src/interfaces/IPlayer.sol";

contract MintDefaultSkinScript is Script {
    function setUp() public {}

    function run(address defaultSkinAddr) public {
        require(defaultSkinAddr != address(0), "DefaultSkin address cannot be zero");

        // Get private key from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        DefaultPlayerSkinNFT defaultSkin = DefaultPlayerSkinNFT(defaultSkinAddr);

        // Skin Index Always 0 for default collection
        uint32 skinIndex = 0;
        uint16 tokenId = defaultSkin.CURRENT_TOKEN_ID();

        // Get the character data - replace getBalancedWarrior with your desired character type
        (
            IGameDefinitions.WeaponType weapon,
            IGameDefinitions.ArmorType armor,
            IGameDefinitions.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, tokenId);

        // Mint the new skin
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, tokenId);

        console2.log("Minted new default skin with ID:", tokenId);

        vm.stopBroadcast();
    }
}
