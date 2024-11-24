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

        playerContract = new Player();
    }

    function _generateRandomSeed(address playerAddress) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, block.prevrandao, blockhash(block.number - 1), playerAddress, address(this)
                )
            )
        );
    }

    function _validatePlayerAttributes(IPlayer.PlayerStats memory stats, string memory context) private pure {
        assertTrue(stats.strength >= 3, string.concat(context, ": Strength below minimum"));
        assertTrue(stats.constitution >= 3, string.concat(context, ": Constitution below minimum"));
        assertTrue(stats.agility >= 3, string.concat(context, ": Agility below minimum"));
        assertTrue(stats.stamina >= 3, string.concat(context, ": Stamina below minimum"));

        assertTrue(stats.strength <= 21, string.concat(context, ": Strength above maximum"));
        assertTrue(stats.constitution <= 21, string.concat(context, ": Constitution above maximum"));
        assertTrue(stats.agility <= 21, string.concat(context, ": Agility above maximum"));
        assertTrue(stats.stamina <= 21, string.concat(context, ": Stamina above maximum"));

        int16 total = int16(stats.strength) + int16(stats.constitution) + int16(stats.agility) + int16(stats.stamina);
        assertEq(total, 48, string.concat(context, ": Total attributes should be 48"));
    }

    function testCreatePlayer() public {
        address player = address(0x1); // Use a specific address
        vm.prank(player); // First creation with this address

        uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp)));
        (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer(randomSeed);

        assertTrue(playerId > 0, "Player ID should be non-zero");
        assertTrue(newPlayer.strength >= 3, "Strength too low");
        _validatePlayerAttributes(newPlayer, "Single player test");

        // Try to create another player with same address - should revert
        vm.prank(player); // Use same address again
        vm.expectRevert(Player.PLAYER_EXISTS.selector);
        playerContract.createPlayer(_generateRandomSeed(player));
    }

    function testMultiplePlayers() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(uint160(i + 1)));
            uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, i)));

            (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer(randomSeed);

            assertTrue(playerId > 0, "Player ID should be non-zero");
            assertTrue(newPlayer.strength >= 3, "Strength too low");
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));
        }
    }
}
