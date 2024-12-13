// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {GelatoVRFConsumerBase} from "../../lib/vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import {IPlayer} from "../../src/interfaces/IPlayer.sol";
import {Player} from "../../src/Player.sol";
import {DefaultPlayerLibrary} from "../../src/lib/DefaultPlayerLibrary.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/IPlayerSkinNFT.sol";
import {DefaultPlayerSkinNFT} from "../../src/DefaultPlayerSkinNFT.sol";
import {PlayerSkinRegistry} from "../../src/PlayerSkinRegistry.sol";
import {IGameEngine} from "../../src/interfaces/IGameEngine.sol";
import {GameEngine} from "../../src/GameEngine.sol";

abstract contract TestBase is Test {
    bool private constant CI_MODE = true;
    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;
    uint256 private constant VRF_ROUND = 335;
    address public operator;

    struct DefaultCharacters {
        uint16 greatswordOffensive;
        uint16 battleaxeOffensive;
        uint16 spearBalanced;
        uint16 swordAndShieldDefensive;
        uint16 rapierAndShieldDefensive;
        uint16 quarterstaffDefensive;
    }

    uint32 public skinIndex;
    DefaultPlayerSkinNFT public defaultSkin;
    PlayerSkinRegistry public skinRegistry;

    function setUp() public virtual {
        operator = address(0x42);
        setupRandomness();
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();

        // Register and configure default skin
        skinIndex = _registerSkin(address(defaultSkin));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setDefaultSkinRegistryId(skinIndex);
        skinRegistry.setDefaultCollection(skinIndex, true);

        // Mint default skin token ID 1
        (
            IPlayerSkinNFT.WeaponType weapon,
            IPlayerSkinNFT.ArmorType armor,
            IPlayerSkinNFT.FightingStance stance,
            IPlayer.PlayerStats memory stats,
            string memory ipfsCID
        ) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 1);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 1);
    }

    function _registerSkin(address skinContract) internal returns (uint32) {
        vm.deal(address(this), skinRegistry.registrationFee());
        vm.prank(address(this));
        return skinRegistry.registerSkin{value: skinRegistry.registrationFee()}(skinContract);
    }

    function setupRandomness() internal {
        // Check if we're in CI environment
        try vm.envString("CI") returns (string memory) {
            console2.log("Testing in CI mode with mock randomness");
            vm.warp(1_000_000);
            vm.roll(DEFAULT_FORK_BLOCK);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Try to use RPC fork, fallback to mock if not available
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                vm.createSelectFork(rpcUrl);
            } catch {
                console2.log("No RPC_URL found, using mock randomness");
                vm.warp(1_000_000);
                vm.roll(DEFAULT_FORK_BLOCK);
                vm.prevrandao(bytes32(uint256(0x1234567890)));
            }
        }
    }

    // Helper function for VRF fulfillment with round matching
    function _fulfillVRF(uint256 requestId, uint256 randomSeed, address vrfConsumer) internal {
        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(VRF_ROUND, data);

        // Call fulfillRandomness as operator
        vm.prank(operator);
        GelatoVRFConsumerBase(vrfConsumer).fulfillRandomness(
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, operator, VRF_ROUND))), dataWithRound
        );
    }

    // Helper to create a player request, stopping before VRF fulfillment.
    // This is useful for testing VRF fulfillment mechanics separately,
    // such as testing operator permissions or invalid round IDs.
    function _createPlayerRequest(address owner, Player playerContract, bool useSetB) internal returns (uint256) {
        vm.deal(owner, playerContract.createPlayerFeeAmount());
        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();
        return requestId;
    }

    // Helper function to create a player with VRF
    function _createPlayerAndFulfillVRF(address owner, Player playerContract, bool useSetB)
        internal
        returns (uint256)
    {
        // Give enough ETH to cover the fee
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        // Request player creation
        uint256 requestId = _createPlayerRequest(owner, playerContract, useSetB);

        // Fulfill VRF request
        _fulfillVRF(
            requestId,
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, VRF_ROUND))),
            address(playerContract)
        );

        // Get the player ID from the contract
        uint256[] memory playerIds = playerContract.getPlayerIds(owner);
        require(playerIds.length > 0, "Player not created");

        return playerIds[playerIds.length - 1];
    }

    // Helper function to assert stat ranges
    function _assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc)
        internal
        pure
        virtual
    {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Calculated stats
        assertTrue(calc.maxHealth > 0);
        assertTrue(calc.maxEndurance > 0);
        assertTrue(calc.damageModifier > 0);
        assertTrue(calc.hitChance > 0);
        assertTrue(calc.blockChance > 0);
        assertTrue(calc.dodgeChance > 0);
        assertTrue(calc.critChance > 0);
        assertTrue(calc.initiative > 0);
        assertTrue(calc.counterChance > 0);
        assertTrue(calc.critMultiplier > 0);
        assertTrue(calc.parryChance > 0);
    }

    // Helper function to create a player loadout that supports both practice and duel game test cases
    function _createLoadout(uint32 playerId, bool usePlayerIdAsTokenId, bool usePlayerStats, Player playerContractRef)
        internal
        view
        returns (IGameEngine.PlayerLoadout memory)
    {
        uint32 loadoutSkinIndex = skinIndex; // Default to test's skinIndex
        uint16 tokenId = usePlayerIdAsTokenId ? uint16(playerId) : 1;

        if (usePlayerStats) {
            IPlayer.PlayerStats memory stats = playerContractRef.getPlayer(playerId);
            loadoutSkinIndex = stats.skinIndex;
        }

        return IGameEngine.PlayerLoadout({playerId: playerId, skinIndex: loadoutSkinIndex, skinTokenId: tokenId});
    }

    // Helper function to validate combat results
    function _assertValidCombatResult(
        uint256 winner,
        GameEngine.WinCondition condition,
        GameEngine.CombatAction[] memory actions,
        uint256 player1Id,
        uint256 player2Id
    ) internal pure {
        assertTrue(winner == player1Id || winner == player2Id, "Invalid winner");
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");
    }

    // Helper function to check if a combat action is offensive
    function _isOffensiveAction(GameEngine.CombatAction memory action) internal pure returns (bool) {
        return action.p1Result == GameEngine.CombatResultType.ATTACK
            || action.p1Result == GameEngine.CombatResultType.CRIT || action.p1Result == GameEngine.CombatResultType.COUNTER
            || action.p1Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE_CRIT
            || action.p2Result == GameEngine.CombatResultType.ATTACK || action.p2Result == GameEngine.CombatResultType.CRIT
            || action.p2Result == GameEngine.CombatResultType.COUNTER
            || action.p2Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE_CRIT;
    }

    // Helper function to check if a combat action is defensive
    function _isDefensiveAction(GameEngine.CombatAction memory action) internal pure returns (bool) {
        return action.p1Result == GameEngine.CombatResultType.BLOCK
            || action.p1Result == GameEngine.CombatResultType.DODGE || action.p1Result == GameEngine.CombatResultType.PARRY
            || action.p1Result == GameEngine.CombatResultType.HIT || action.p1Result == GameEngine.CombatResultType.MISS
            || action.p1Result == GameEngine.CombatResultType.COUNTER
            || action.p1Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE
            || action.p1Result == GameEngine.CombatResultType.RIPOSTE_CRIT
            || action.p2Result == GameEngine.CombatResultType.BLOCK || action.p2Result == GameEngine.CombatResultType.DODGE
            || action.p2Result == GameEngine.CombatResultType.PARRY || action.p2Result == GameEngine.CombatResultType.HIT
            || action.p2Result == GameEngine.CombatResultType.MISS || action.p2Result == GameEngine.CombatResultType.COUNTER
            || action.p2Result == GameEngine.CombatResultType.COUNTER_CRIT
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE
            || action.p2Result == GameEngine.CombatResultType.RIPOSTE_CRIT;
    }

    // Helper function to check if a combat result is defensive
    function _isDefensiveResult(GameEngine.CombatResultType result) internal pure returns (bool) {
        return result == GameEngine.CombatResultType.PARRY || result == GameEngine.CombatResultType.BLOCK
            || result == GameEngine.CombatResultType.DODGE || result == GameEngine.CombatResultType.MISS
            || result == GameEngine.CombatResultType.HIT;
    }

    // Helper function to generate a deterministic but unpredictable seed for game actions
    function _generateGameSeed() internal view returns (uint256) {
        return uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, blockhash(block.number - 1), msg.sender))
        );
    }

    // Helper function to simulate VRF fulfillment with standard test data
    function _simulateVRFFulfillment(uint256 requestId, uint256 roundId) internal returns (bytes memory) {
        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(roundId, innerData);
        return dataWithRound;
    }

    // Helper function to decode VRF event logs
    function _decodeVRFRequestEvent(Vm.Log[] memory entries)
        internal
        pure
        returns (uint256 roundId, bytes memory eventData)
    {
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RequestedRandomness(uint256,bytes)")) {
                (roundId, eventData) = abi.decode(entries[i].data, (uint256, bytes));
                break;
            }
        }
        return (roundId, eventData);
    }

    // Helper function to assert player ownership and basic state
    function _assertPlayerState(Player playerContract, uint256 playerId, address expectedOwner, bool shouldExist)
        internal
    {
        if (shouldExist) {
            assertEq(playerContract.getPlayerOwner(playerId), expectedOwner, "Incorrect player owner");
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
            assertTrue(stats.strength != 0, "Player should exist");
            assertFalse(playerContract.isPlayerRetired(playerId), "Player should not be retired");
        } else {
            vm.expectRevert();
            playerContract.getPlayerOwner(playerId);
        }
    }

    // Helper function to assert ETH balances after transactions
    function _assertBalances(address account, uint256 expectedBalance, string memory message) internal {
        assertEq(account.balance, expectedBalance, message);
    }
}
