// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Player} from "../../src/fighters/Player.sol";
import {PlayerDataCodec} from "../../src/lib/PlayerDataCodec.sol";
import {DefaultPlayer} from "../../src/fighters/DefaultPlayer.sol";
import {DefaultPlayerSkinNFT} from "../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import {DefaultPlayerLibrary} from "../../src/fighters/lib/DefaultPlayerLibrary.sol";
import {PlayerSkinRegistry} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {Monster} from "../../src/fighters/Monster.sol";
import {MonsterLibrary} from "../../src/fighters/lib/MonsterLibrary.sol";
import {MonsterSkinNFT} from "../../src/nft/skins/MonsterSkinNFT.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

contract FighterDeployScript is Script {
    function setUp() public {}

    function run(
        address skinRegistryAddr,
        address nameRegistryAddr,
        address monsterNameRegistryAddr,
        address equipmentRequirementsAddr,
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 keyHash
    ) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PlayerDataCodec helper contract
        PlayerDataCodec playerDataCodec = new PlayerDataCodec();

        // 2. Deploy PlayerTickets contract (requires nameRegistry)
        PlayerTickets playerTickets = new PlayerTickets(
            nameRegistryAddr,
            "bafybeib2pydnkibnj5o3udxg2grmh4dt2tztcecccka4rxia5xumqpemjm", // Fungible metadata CID
            "bafybeibgu5ach7brer6jcjqcgtacxn2ltmgxwencxmcmlf3jt5mmwhxrje" // Name change image CID
        );

        // 3. Deploy Player contract with Chainlink VRF coordinator, equipment requirements, and playerTickets
        Player playerContract = new Player(
            skinRegistryAddr,
            nameRegistryAddr,
            equipmentRequirementsAddr,
            vrfCoordinator,
            subscriptionId,
            keyHash,
            address(playerTickets),
            address(playerDataCodec)
        );

        // 4. Deploy DefaultPlayer and Monster contracts
        DefaultPlayer defaultPlayerContract = new DefaultPlayer(skinRegistryAddr, nameRegistryAddr);
        Monster monsterContract = new Monster(skinRegistryAddr, monsterNameRegistryAddr);

        // 5. Deploy and setup DefaultPlayerSkinNFT
        DefaultPlayerSkinNFT defaultSkin = new DefaultPlayerSkinNFT();
        MonsterSkinNFT monsterSkin = new MonsterSkinNFT();

        // Register default skin collection
        uint32 defaultSkinIndex = PlayerSkinRegistry(payable(skinRegistryAddr)).registerSkin(address(defaultSkin));
        uint32 monsterSkinIndex = PlayerSkinRegistry(payable(skinRegistryAddr)).registerSkin(address(monsterSkin));

        // Set as DefaultPlayer type
        PlayerSkinRegistry(payable(skinRegistryAddr))
            .setSkinType(defaultSkinIndex, IPlayerSkinRegistry.SkinType.DefaultPlayer);
        PlayerSkinRegistry(payable(skinRegistryAddr))
            .setSkinType(monsterSkinIndex, IPlayerSkinRegistry.SkinType.Monster);

        // Set verification
        PlayerSkinRegistry(payable(skinRegistryAddr)).setSkinVerification(defaultSkinIndex, true);
        PlayerSkinRegistry(payable(skinRegistryAddr)).setSkinVerification(monsterSkinIndex, true);

        // 6. Mint initial characters
        console2.log("\n=== Minting Default Characters ===");
        DefaultPlayerLibrary.createAllDefaultCharacters(defaultSkin, defaultPlayerContract, defaultSkinIndex);

        console2.log("\n=== Minting Monsters ===");
        MonsterLibrary.createAllMonsters(monsterSkin, monsterContract, monsterSkinIndex);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("PlayerDataCodec:", address(playerDataCodec));
        console2.log("Player:", address(playerContract));
        console2.log("PlayerTickets:", address(playerTickets));
        console2.log("DefaultPlayer:", address(defaultPlayerContract));
        console2.log("Monster:", address(monsterContract));
        console2.log("DefaultPlayerSkinNFT:", address(defaultSkin));
        console2.log("MonsterSkinNFT:", address(monsterSkin));
        console2.log("Default Skin Registry Index:", defaultSkinIndex);
        console2.log("Monster Skin Registry Index:", monsterSkinIndex);

        vm.stopBroadcast();
    }
}
