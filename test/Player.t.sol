// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Player} from "../src/Player.sol";
import "../src/interfaces/IPlayer.sol";

contract PlayerTest is Test {
    Player public playerContract;

    function setUp() public {
        // Check if we're in CI environment
        try vm.envString("CI") returns (string memory) {
            // In CI: use mock data
            vm.warp(1_000_000);
            vm.roll(16_000_000);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Local dev: require live blockchain data
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                revert(
                    "RPC_URL environment variable not set - tests require live blockchain data for local development"
                );
            }
        }

        playerContract = new Player(5);
    }

    function _validatePlayerAttributes(IPlayer.PlayerStats memory stats, string memory context) private pure {
        // Check minimum values
        assertTrue(stats.strength >= 3, string.concat(context, ": Strength below minimum"));
        assertTrue(stats.constitution >= 3, string.concat(context, ": Constitution below minimum"));
        assertTrue(stats.size >= 3, string.concat(context, ": Size below minimum"));
        assertTrue(stats.agility >= 3, string.concat(context, ": Agility below minimum"));
        assertTrue(stats.stamina >= 3, string.concat(context, ": Stamina below minimum"));
        assertTrue(stats.luck >= 3, string.concat(context, ": Luck below minimum"));

        // Check maximum values
        assertTrue(stats.strength <= 21, string.concat(context, ": Strength above maximum"));
        assertTrue(stats.constitution <= 21, string.concat(context, ": Constitution above maximum"));
        assertTrue(stats.size <= 21, string.concat(context, ": Size above maximum"));
        assertTrue(stats.agility <= 21, string.concat(context, ": Agility above maximum"));
        assertTrue(stats.stamina <= 21, string.concat(context, ": Stamina above maximum"));
        assertTrue(stats.luck <= 21, string.concat(context, ": Luck above maximum"));

        // Calculate total using uint16 to prevent any overflow
        uint16 total = uint16(stats.strength) + uint16(stats.constitution) + uint16(stats.size) + uint16(stats.agility)
            + uint16(stats.stamina) + uint16(stats.luck);

        assertEq(total, 72, string.concat(context, ": Total attributes should be 72"));
    }

    function testCreatePlayer() public {
        address player = address(0x1);
        vm.prank(player);

        (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer();

        assertTrue(playerId > 0, "Player ID should be non-zero");
        assertTrue(newPlayer.strength >= 3, "Strength too low");
        _validatePlayerAttributes(newPlayer, "Single player test");
    }

    function testMultiplePlayers() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(uint160(i + 1)));

            (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer();

            assertTrue(playerId > 0, "Player ID should be non-zero");
            assertTrue(newPlayer.strength >= 3, "Strength too low");
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));
        }
    }
}
