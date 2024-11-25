// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {Player} from "../src/Player.sol";

contract GameScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        Player playerContract = new Player();
        Game game = new Game(address(playerContract));
        vm.stopBroadcast();
    }
}
