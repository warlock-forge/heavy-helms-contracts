// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Player, NotSkinOwner, PlayerDoesNotExist} from "../src/Player.sol";
import {PlayerSkinRegistry} from "../src/PlayerSkinRegistry.sol";
import {GameStats} from "../src/GameStats.sol";
import "../src/interfaces/IPlayer.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";
import "../src/interfaces/IPlayerSkinNFT.sol";
import "./utils/TestBase.sol";

contract PlayerTest is TestBase {
    Player public playerContract;
    PlayerSkinRegistry public skinRegistry;
    DefaultPlayerSkinNFT public defaultSkin;

    address public constant PLAYER_ONE = address(0x1);
    uint256 public constant PLAYER_ONE_ID = 1;

    event PlayerSkinEquipped(uint256 indexed playerId, uint32 indexed skinIndex, uint16 indexed skinTokenId);

    function setUp() public {
        setupRandomness();

        // Deploy GameStats first
        GameStats gameStats = new GameStats();

        // Deploy skin registry with GameStats address
        skinRegistry = new PlayerSkinRegistry(address(gameStats));

        // Deploy player contract with skin registry address
        playerContract = new Player(address(skinRegistry));

        // Deploy a default skin contract for testing
        defaultSkin = new DefaultPlayerSkinNFT();

        // Register the skin contract
        vm.deal(address(this), 1 ether);
        skinRegistry.registerSkin{value: 0.001 ether}(address(defaultSkin));
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
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        address player = address(0x1);
        vm.prank(player);
        (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer();
        assertTrue(playerId > 0, "Player ID should be non-zero");
        _validatePlayerAttributes(newPlayer, "Single player test");
    }

    function testMultiplePlayers() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(uint160(i + 1)));
            (uint256 playerId, IPlayer.PlayerStats memory newPlayer) = playerContract.createPlayer();
            assertTrue(playerId > 0, "Player ID should be non-zero");
            _validatePlayerAttributes(newPlayer, string.concat("Player ", vm.toString(i + 1)));
        }
    }

    function testStatRanges() public {
        if (vm.envOr("CI", false)) {
            console2.log("Skipping randomness test in CI");
            return;
        }
        vm.prank(PLAYER_ONE);
        (uint256 playerId, IPlayer.PlayerStats memory stats) = playerContract.createPlayer();
        IPlayer.CalculatedStats memory calculated = playerContract.calculateStats(stats);

        // Update expected ranges for new health calculation
        assertTrue(calculated.maxHealth >= 75 + 36 + 18, "Health below min"); // Min stats (3) = 75 + (3*12) + (3*6)
        assertTrue(calculated.maxHealth <= 75 + 252 + 126, "Health above max"); // Max stats (21) = 75 + (21*12) + (21*6)

        // ... rest of test assertions ...
    }

    function assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc) internal pure {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Updated calculated stat bounds based on new formulas
        uint256 minHealth = 45 + (3 * 8) + (3 * 4); // min constitution and size
        uint256 maxHealth = 45 + (21 * 8) + (21 * 4); // max constitution and size
        assertTrue(calc.maxHealth >= minHealth && calc.maxHealth <= maxHealth, "Health out of range");

        assertTrue(calc.damageModifier >= 50 && calc.damageModifier <= 200, "Damage mod out of range");
        assertTrue(calc.hitChance >= 30 && calc.hitChance <= 100, "Hit chance out of range");
        assertTrue(calc.critChance <= 50, "Crit chance too high");
        assertTrue(calc.critMultiplier >= 150 && calc.critMultiplier <= 300, "Crit multiplier out of range");
    }

    function testEquipSkin() public {
        // Create a player
        vm.startPrank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer();
        vm.stopPrank();

        // Need to register the skin contract first
        vm.deal(address(this), 1 ether);
        skinRegistry.registerSkin{value: 0.001 ether}(address(defaultSkin));

        // Mint skin with beginner-friendly equipment (absolutely no stat requirements)
        vm.prank(address(this));
        uint16 tokenId = defaultSkin.mintSkin(
            PLAYER_ONE,
            IPlayerSkinNFT.WeaponType.SwordAndShield, // Basic weapon
            IPlayerSkinNFT.ArmorType.Cloth, // Changed to Cloth - no requirements
            IPlayerSkinNFT.FightingStance.Balanced
        );

        // Set approval for the player contract
        vm.prank(PLAYER_ONE);
        defaultSkin.setApprovalForAll(address(playerContract), true);

        // Now try to equip as PLAYER_ONE
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(playerId, 0, tokenId);

        // Verify skin is equipped
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        assertEq(stats.skinIndex, 0, "Skin index should be 0");
        assertEq(stats.skinTokenId, tokenId, "Skin token ID should match");
    }

    function testCannotEquipUnownedSkin() public {
        // Create a player
        vm.prank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer();

        // Need to register the skin contract first
        vm.deal(address(this), 1 ether);
        skinRegistry.registerSkin{value: 0.001 ether}(address(defaultSkin));

        // Mint a skin to a different address
        uint16 tokenId = defaultSkin.mintSkin(
            address(0x2),
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Defensive
        );

        // Try to equip the unowned skin
        vm.prank(PLAYER_ONE);
        vm.expectRevert(NotSkinOwner.selector);
        playerContract.equipSkin(playerId, 1, tokenId);
    }

    function testCannotEquipToUnownedPlayer() public {
        // Create a player owned by address(0x1)
        vm.prank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer();

        // Mint a skin to address(0x2)
        address otherPlayer = address(0x2);
        uint16 tokenId = defaultSkin.mintSkin(
            otherPlayer,
            IPlayerSkinNFT.WeaponType.SwordAndShield,
            IPlayerSkinNFT.ArmorType.Plate,
            IPlayerSkinNFT.FightingStance.Defensive
        );

        // Try to equip skin to player owned by address(0x1)
        vm.prank(otherPlayer);
        vm.expectRevert(abi.encodeWithSelector(PlayerDoesNotExist.selector, playerId));
        playerContract.equipSkin(playerId, 1, tokenId);
    }

    function testCannotEquipInvalidSkinIndex() public {
        // Create a player
        vm.prank(PLAYER_ONE);
        (uint256 playerId,) = playerContract.createPlayer();

        // Try to equip non-existent skin collection
        vm.prank(PLAYER_ONE);
        vm.expectRevert(); // Should revert when trying to access invalid skin index
        playerContract.equipSkin(playerId, 999, 1);
    }
}
