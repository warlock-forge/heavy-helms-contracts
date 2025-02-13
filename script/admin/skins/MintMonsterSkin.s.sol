// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MonsterSkinNFT} from "../../../src/MonsterSkinNFT.sol";
import {MonsterLibrary} from "../../../src/lib/MonsterLibrary.sol";
import {Monster} from "../../../src/Monster.sol";

contract MintMonsterSkinScript is Script {
    function run(address monsterSkinAddr, address monsterAddr, MonsterLibrary.MonsterType monsterType) public {
        require(monsterSkinAddr != address(0), "MonsterSkin address cannot be zero");
        require(monsterAddr != address(0), "Monster address cannot be zero");

        // Get private key from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        MonsterSkinNFT monsterSkin = MonsterSkinNFT(monsterSkinAddr);
        Monster monster = Monster(monsterAddr);

        uint32 monsterSkinIndex = 1; // Monster collection index
        uint16 tokenId = uint16(monsterType) + 1;

        // Create the monster using the library's public interface
        MonsterLibrary.createMonster(monsterSkin, monster, monsterSkinIndex, tokenId, monsterType);

        console2.log("Created monster type:", uint8(monsterType));
        console2.log("Token ID:", tokenId);

        vm.stopBroadcast();
    }
}
