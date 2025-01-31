// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Player} from "../../../src/Player.sol";
import {IPlayer} from "../../../src/interfaces/IPlayer.sol";

contract WhitelistGameScript is Script {
    function setUp() public {}

    function run(address gameAddr, address playerAddr) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        Player playerContract = Player(playerAddr);
        IPlayer.GamePermissions memory perms =
            IPlayer.GamePermissions({record: true, retire: false, name: false, attributes: false, immortal: false});
        playerContract.setGameContractPermission(gameAddr, perms);
        console.log("Game contract permission set:", gameAddr);

        vm.stopBroadcast();
    }
}
