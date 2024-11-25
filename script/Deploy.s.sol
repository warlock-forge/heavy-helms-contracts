// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";

contract DeployScript is Script {
    function run() public returns (Game) {
        vm.startBroadcast();
        Player player = new Player();
        Game implementation = new Game(address(player));
        vm.stopBroadcast();
        return implementation;
    }
}
