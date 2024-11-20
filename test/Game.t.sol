// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";

contract GameTest is Test {
    Game public game;

    function setUp() public {
        // For CI environment, use a mock chain
        try vm.envString("RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
        } catch {
            // If RPC_URL is not available, use a local mock setup
            vm.warp(1_000_000);
            vm.roll(16_000_000);
            // Mock prevrandao value
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        }
        game = new Game();
    }

    function _generateRandomSeed(address player) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), player, address(this))
            )
        );
    }

    function _validatePlayerAttributes(Game.Player memory player, string memory context) private pure {
        assertTrue(player.strength >= 3, string.concat(context, ": Strength below minimum"));
        assertTrue(player.constitution >= 3, string.concat(context, ": Constitution below minimum"));
        assertTrue(player.agility >= 3, string.concat(context, ": Agility below minimum"));
        assertTrue(player.stamina >= 3, string.concat(context, ": Stamina below minimum"));

        assertTrue(player.strength <= 21, string.concat(context, ": Strength above maximum"));
        assertTrue(player.constitution <= 21, string.concat(context, ": Constitution above maximum"));
        assertTrue(player.agility <= 21, string.concat(context, ": Agility above maximum"));
        assertTrue(player.stamina <= 21, string.concat(context, ": Stamina above maximum"));

        int16 total =
            int16(player.strength) + int16(player.constitution) + int16(player.agility) + int16(player.stamina);
        assertEq(total, 48, string.concat(context, ": Total attributes should be 48"));
    }

    function testCreatePlayer() public {
        address player = address(1);

        // First creation should succeed
        vm.prank(player);
        uint256 randomSeed = _generateRandomSeed(player);
        Game.Player memory newPlayer = game.createPlayer(randomSeed);
        _validatePlayerAttributes(newPlayer, "Single player test");

        // Second creation with same address should revert
        vm.prank(player);
        vm.expectRevert(Game.PLAYER_EXISTS.selector);
        game.createPlayer(_generateRandomSeed(player));
    }

    function testMultiplePlayers() public {
        string memory stats = "";
        for (uint256 i = 0; i < 5; i++) {
            address player = address(uint160(i + 1));
            vm.prank(player);

            uint256 randomSeed = _generateRandomSeed(player);
            Game.Player memory newPlayer = game.createPlayer(randomSeed);
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));

            stats = string.concat(
                stats,
                i == 0 ? "" : " | ",
                string.concat(
                    "P",
                    vm.toString(i + 1),
                    ": ",
                    vm.toString(uint8(newPlayer.strength)),
                    "/",
                    vm.toString(uint8(newPlayer.constitution)),
                    "/",
                    vm.toString(uint8(newPlayer.agility)),
                    "/",
                    vm.toString(uint8(newPlayer.stamina))
                )
            );
        }
        console.log("Player Stats (STR/CON/AGI/STA):", stats);
    }
}
