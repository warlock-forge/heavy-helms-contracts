// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Game.sol";
import "../src/GameFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Game implementation = new Game();

        GameFactory factory = new GameFactory(address(implementation));

        vm.stopBroadcast();

        console.log("Implementation deployed to:", address(implementation));
        console.log("Factory deployed to:", address(factory));
        console.log("Beacon address:", address(factory.beacon()));
    }
}
