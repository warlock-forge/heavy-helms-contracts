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
            vm.warp(1_000_000);
            vm.roll(16_000_000);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                revert("RPC_URL environment variable not set");
            }
        }
        playerContract = new Player();
    }

    function _validatePlayerAttributes(IPlayer.PlayerStats memory stats, string memory context) private pure {
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        uint16 total = uint16(stats.strength) + uint16(stats.constitution) + uint16(stats.size) + uint16(stats.agility)
            + uint16(stats.stamina) + uint16(stats.luck);
        assertEq(total, 72, string.concat(context, ": Total attributes should be 72"));
    }

    function testCreatePlayer() public {
        address player = address(0x1);
        vm.prank(player);
        (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer();
        assertTrue(playerId > 0, "Player ID should be non-zero");
        _validatePlayerAttributes(newPlayer, "Single player test");
    }

    function testMultiplePlayers() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(uint160(i + 1)));
            (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer();
            assertTrue(playerId > 0, "Player ID should be non-zero");
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));
        }
    }

    function testStatRanges() public {
        (, IPlayer.PlayerStats memory stats1) = playerContract.createPlayer();
        IPlayer.CalculatedStats memory calc1 = playerContract.calculateStats(stats1);
        assertStatRanges(stats1, calc1);
    }

    function assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc) internal pure {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Calculated stat bounds
        assertTrue(calc.maxHealth >= 100 && calc.maxHealth <= 300, "Health out of range");
        assertTrue(calc.damageModifier >= 50 && calc.damageModifier <= 200, "Damage mod out of range");
        assertTrue(calc.hitChance >= 30 && calc.hitChance <= 100, "Hit chance out of range");
        assertTrue(calc.critChance <= 50, "Crit chance too high");
        assertTrue(calc.critMultiplier >= 150 && calc.critMultiplier <= 300, "Crit multiplier out of range");
    }
}
