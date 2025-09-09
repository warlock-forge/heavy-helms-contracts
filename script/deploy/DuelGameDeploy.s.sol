// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {DuelGame} from "../../src/game/modes/DuelGame.sol";
import {Player} from "../../src/fighters/Player.sol";
import {IPlayer} from "../../src/interfaces/fighters/IPlayer.sol";

contract DuelGameDeployScript is Script {
    function setUp() public {}

    function run(
        address gameEngineAddr,
        address payable playerAddr,
        address playerTicketsAddr,
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 keyHash
    ) public {
        require(gameEngineAddr != address(0), "GameEngine address cannot be zero");
        require(playerAddr != address(0), "Player address cannot be zero");
        require(playerTicketsAddr != address(0), "PlayerTickets address cannot be zero");

        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DuelGame
        DuelGame duelGame =
            new DuelGame(gameEngineAddr, playerAddr, vrfCoordinator, subscriptionId, keyHash, playerTicketsAddr);

        // Whitelist DuelGame in Player contract
        Player playerContract = Player(playerAddr);
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, immortal: false, experience: false});
        playerContract.setGameContractPermission(address(duelGame), perms);

        console2.log("\n=== Deployed Addresses ===");
        console2.log("DuelGame:", address(duelGame));
        console2.log("DuelGame whitelisted in Player contract");

        vm.stopBroadcast();
    }
}
