// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Game} from "../src/Game.sol";

contract GameScript is Script {
    Game public counter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        counter = new Game();

        vm.stopBroadcast();
    }
}
