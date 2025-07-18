// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {GameEngine} from "../../src/game/engine/GameEngine.sol";
import {Player} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";

contract DuelGameDeployScript is Script {
    function setUp() public {}

    function run(address gameEngineAddr, address playerAddr) public {
        require(gameEngineAddr != address(0), "GameEngine address cannot be zero");
        require(playerAddr != address(0), "Player address cannot be zero");

        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");
        address operator = vm.envAddress("GELATO_VRF_OPERATOR");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DuelGame
        DuelGame duelGame = new DuelGame(gameEngineAddr, playerAddr, operator);

        // Whitelist DuelGame in Player contract
        Player playerContract = Player(playerAddr);
        IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
            record: true,
            retire: false,
            attributes: false,
            immortal: false,
            experience: false
        });
        playerContract.setGameContractPermission(address(duelGame), perms);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("DuelGame:", address(duelGame));
        console2.log("DuelGame whitelisted in Player contract");

        vm.stopBroadcast();
    }
}
