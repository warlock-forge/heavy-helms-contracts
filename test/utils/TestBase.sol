// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {GelatoVRFConsumerBase} from "../../lib/vrf-contracts/contracts/GelatoVRFConsumerBase.sol";

// Interfaces
import {IPlayer} from "../../src/interfaces/IPlayer.sol";
import {IDefaultPlayer} from "../../src/interfaces/IDefaultPlayer.sol";
import {IMonster} from "../../src/interfaces/IMonster.sol";
import {IGameEngine} from "../../src/interfaces/IGameEngine.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/IPlayerSkinNFT.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/IPlayerSkinRegistry.sol";

// Concrete implementations (needed for deployment)
import {Player} from "../../src/Player.sol";
import {DefaultPlayer} from "../../src/DefaultPlayer.sol";
import {Monster} from "../../src/Monster.sol";
import {GameEngine} from "../../src/GameEngine.sol";
import {DefaultPlayerSkinNFT} from "../../src/DefaultPlayerSkinNFT.sol";
import {PlayerSkinRegistry} from "../../src/PlayerSkinRegistry.sol";
import {PlayerNameRegistry} from "../../src/PlayerNameRegistry.sol";

// Libraries
import {DefaultPlayerLibrary} from "../../src/lib/DefaultPlayerLibrary.sol";
import {GameHelpers} from "../../src/lib/GameHelpers.sol";

abstract contract TestBase is Test {
    bool private constant CI_MODE = true;
    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;
    uint256 private constant VRF_ROUND = 335;
    address public operator;
    Player public playerContract;
    DefaultPlayer public defaultPlayerContract;
    Monster public monsterContract;

    /// @notice Modifier to skip tests in CI environment
    /// @dev Uses vm.envOr to check if CI environment variable is set
    modifier skipInCI() {
        if (!vm.envOr("CI", false)) {
            _;
        }
    }

    /// @notice Struct to hold default character IDs
    struct DefaultCharacters {
        uint16 greatswordOffensive;
        uint16 battleaxeOffensive;
        uint16 spearBalanced;
        uint16 swordAndShieldDefensive;
        uint16 rapierAndShieldDefensive;
        uint16 quarterstaffDefensive;
    }

    DefaultCharacters public chars;
    DefaultPlayerSkinNFT public defaultSkin;
    PlayerSkinRegistry public skinRegistry;
    PlayerNameRegistry public nameRegistry;
    uint32 public skinIndex;
    GameEngine public gameEngine;

    function setUp() public virtual {
        operator = address(0x42);
        setupRandomness();
        skinRegistry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();

        // Register and configure default skin
        skinIndex = _registerSkin(address(defaultSkin));
        skinRegistry.setSkinVerification(skinIndex, true);
        skinRegistry.setSkinType(skinIndex, IPlayerSkinRegistry.SkinType.DefaultPlayer);

        _mintDefaultCharacters();

        // Create name registry
        nameRegistry = new PlayerNameRegistry();

        gameEngine = new GameEngine();

        // Create the player contracts with all required dependencies
        playerContract = new Player(address(skinRegistry), address(nameRegistry), operator);
        defaultPlayerContract = new DefaultPlayer(address(skinRegistry), address(nameRegistry));
        monsterContract = new Monster(address(skinRegistry), address(nameRegistry));

        // Set up the test environment with a proper timestamp
        vm.warp(1692803367 + 1000); // Set timestamp to after genesis
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
    function _fulfillVRF(uint256 requestId, uint256, /* randomSeed */ address vrfConsumer) internal {
        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(VRF_ROUND, data);

        // Call fulfillRandomness as operator
        vm.prank(operator);
        playerContract.fulfillRandomness(uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound);
    }

    // Helper to create a player request, stopping before VRF fulfillment.
    // This is useful for testing VRF fulfillment mechanics separately,
    // such as testing operator permissions or invalid round IDs.
    function _createPlayerRequest(address owner, IPlayer contractInstance, bool useSetB) internal returns (uint256) {
        vm.deal(owner, contractInstance.createPlayerFeeAmount());
        vm.startPrank(owner);
        uint256 requestId = Player(address(contractInstance)).requestCreatePlayer{
            value: Player(address(contractInstance)).createPlayerFeeAmount()
        }(useSetB);
        vm.stopPrank();
        return requestId;
    }

    // Helper function to create a player with VRF
    function _createPlayerAndFulfillVRF(address owner, Player contractInstance, bool useSetB)
        internal
        returns (uint32)
    {
        // Give enough ETH to cover the fee
        vm.deal(owner, contractInstance.createPlayerFeeAmount());

        // Request player creation
        uint256 requestId = _createPlayerRequest(owner, contractInstance, useSetB);

        // Fulfill VRF request
        _fulfillVRF(
            requestId,
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, VRF_ROUND))),
            address(contractInstance)
        );

        // Get the player ID from the contract
        uint32[] memory playerIds = contractInstance.getPlayerIds(owner);
        require(playerIds.length > 0, "Player not created");

        return playerIds[playerIds.length - 1];
    }

    // Helper function to assert stat ranges
    function _assertStatRanges(IPlayer.PlayerStats memory stats) internal pure virtual {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21, "Strength out of range");
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21, "Constitution out of range");
        assertTrue(stats.size >= 3 && stats.size <= 21, "Size out of range");
        assertTrue(stats.agility >= 3 && stats.agility <= 21, "Agility out of range");
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21, "Stamina out of range");
        assertTrue(stats.luck >= 3 && stats.luck <= 21, "Luck out of range");
    }

    // Helper function to create a player loadout that supports both practice and duel game test cases
    function _createLoadout(uint32 fighterId) internal view returns (IGameEngine.PlayerLoadout memory) {
        uint32 loadoutSkinIndex = skinIndex; // Default to test's skinIndex
        uint16 tokenId = 1; // Default token ID

        GameHelpers.PlayerType fighterType = GameHelpers.getPlayerType(fighterId);

        // Get skin index based on fighter type
        if (fighterType == GameHelpers.PlayerType.DefaultPlayer) {
            IDefaultPlayer.DefaultPlayerStats memory stats = defaultPlayerContract.getDefaultPlayer(fighterId);
            loadoutSkinIndex = stats.skinIndex;
            tokenId = stats.skinTokenId;
        } else if (fighterType == GameHelpers.PlayerType.Monster) {
            IMonster.MonsterStats memory stats = monsterContract.getMonster(fighterId);
            loadoutSkinIndex = stats.skinIndex;
            tokenId = stats.skinTokenId;
        } else {
            // PlayerCharacter
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(fighterId);
            loadoutSkinIndex = stats.skinIndex;
            tokenId = stats.skinTokenId;
        }

        return IGameEngine.PlayerLoadout({playerId: fighterId, skinIndex: loadoutSkinIndex, skinTokenId: tokenId});
    }

    // Helper function to validate combat results
    function _assertValidCombatResult(
        uint256 winner,
        uint16 version,
        GameEngine.WinCondition condition,
        GameEngine.CombatAction[] memory actions,
        uint256 player1Id,
        uint256 player2Id
    ) internal pure {
        assertTrue(winner == player1Id || winner == player2Id, "Invalid winner");
        assertTrue(actions.length > 0, "No actions recorded");
        assertTrue(uint8(condition) <= uint8(type(GameEngine.WinCondition).max), "Invalid win condition");
        assertTrue(version > 0, "Invalid version");
    }

    // Helper function to validate events
    function _assertValidCombatEvent(bytes32 player1Data, bytes32 player2Data) internal {
        // Get the last CombatResult event and validate the packed data
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        bytes32 eventPlayer1Data;
        bytes32 eventPlayer2Data;

        for (uint256 i = entries.length; i > 0; i--) {
            // CombatResult event has 4 topics (event sig + 3 indexed params)
            if (entries[i - 1].topics.length == 4) {
                eventPlayer1Data = bytes32(entries[i - 1].topics[1]);
                eventPlayer2Data = bytes32(entries[i - 1].topics[2]);
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "CombatResult event not found");

        // Decode both expected and actual player data
        (
            uint32 expectedId1,
            uint8 expectedStr1,
            uint8 expectedCon1,
            uint8 expectedSize1,
            uint8 expectedAgi1,
            uint8 expectedSta1,
            uint8 expectedLuck1
        ) = abi.decode(abi.encodePacked(uint96(0), player1Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8));

        (
            uint32 actualId1,
            uint8 actualStr1,
            uint8 actualCon1,
            uint8 actualSize1,
            uint8 actualAgi1,
            uint8 actualSta1,
            uint8 actualLuck1
        ) = abi.decode(
            abi.encodePacked(uint96(0), eventPlayer1Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8)
        );

        // Verify player 1 data
        assertEq(actualId1, expectedId1, "Player 1 ID mismatch");
        assertEq(actualStr1, expectedStr1, "Player 1 strength mismatch");
        assertEq(actualCon1, expectedCon1, "Player 1 constitution mismatch");
        assertEq(actualSize1, expectedSize1, "Player 1 size mismatch");
        assertEq(actualAgi1, expectedAgi1, "Player 1 agility mismatch");
        assertEq(actualSta1, expectedSta1, "Player 1 stamina mismatch");
        assertEq(actualLuck1, expectedLuck1, "Player 1 luck mismatch");

        // Decode and verify player 2 data
        (
            uint32 expectedId2,
            uint8 expectedStr2,
            uint8 expectedCon2,
            uint8 expectedSize2,
            uint8 expectedAgi2,
            uint8 expectedSta2,
            uint8 expectedLuck2
        ) = abi.decode(abi.encodePacked(uint96(0), player2Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8));

        (
            uint32 actualId2,
            uint8 actualStr2,
            uint8 actualCon2,
            uint8 actualSize2,
            uint8 actualAgi2,
            uint8 actualSta2,
            uint8 actualLuck2
        ) = abi.decode(
            abi.encodePacked(uint96(0), eventPlayer2Data), (uint32, uint8, uint8, uint8, uint8, uint8, uint8)
        );

        // Verify player 2 data
        assertEq(actualId2, expectedId2, "Player 2 ID mismatch");
        assertEq(actualStr2, expectedStr2, "Player 2 strength mismatch");
        assertEq(actualCon2, expectedCon2, "Player 2 constitution mismatch");
        assertEq(actualSize2, expectedSize2, "Player 2 size mismatch");
        assertEq(actualAgi2, expectedAgi2, "Player 2 agility mismatch");
        assertEq(actualSta2, expectedSta2, "Player 2 stamina mismatch");
        assertEq(actualLuck2, expectedLuck2, "Player 2 luck mismatch");
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
    function _assertPlayerState(Player contractInstance, uint32 playerId, address expectedOwner, bool shouldExist)
        internal
    {
        if (shouldExist) {
            assertEq(contractInstance.getPlayerOwner(playerId), expectedOwner, "Incorrect player owner");
            IPlayer.PlayerStats memory stats = contractInstance.getPlayer(playerId);
            assertTrue(stats.strength != 0, "Player should exist");
            assertFalse(contractInstance.isPlayerRetired(playerId), "Player should not be retired");
        } else {
            vm.expectRevert();
            contractInstance.getPlayerOwner(playerId);
        }
    }

    // Helper function to assert ETH balances after transactions
    function _assertBalances(address account, uint256 expectedBalance, string memory message) internal {
        assertEq(account.balance, expectedBalance, message);
    }

    // Helper function to assert VRF request
    function _assertVRFRequest(uint256 requestId, uint256 roundId) internal {
        // Get recorded logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Look for the VRF request event
        bool foundEvent = false;
        for (uint256 i = entries.length; i > 0; i--) {
            if (entries[i - 1].topics[0] == keccak256("RequestedRandomness(uint256,bytes)")) {
                // Found event, verify round ID matches
                assertEq(uint256(entries[i - 1].topics[1]), roundId, "VRF round ID mismatch");
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "VRF request event not found");
    }

    // Helper function to convert PlayerLoadout to FighterStats
    function _convertToLoadout(IGameEngine.PlayerLoadout memory playerLoadout)
        internal
        view
        returns (IGameEngine.FighterStats memory)
    {
        // Get skin info and attributes
        PlayerSkinRegistry.SkinInfo memory skinInfo = playerContract.skinRegistry().getSkin(playerLoadout.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory attrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(playerLoadout.skinTokenId);

        // Get base stats based on fighter type
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;

        GameHelpers.PlayerType fighterType = GameHelpers.getPlayerType(playerLoadout.playerId);

        if (fighterType == GameHelpers.PlayerType.DefaultPlayer) {
            IDefaultPlayer.DefaultPlayerStats memory stats =
                defaultPlayerContract.getDefaultPlayer(playerLoadout.playerId);
            strength = stats.strength;
            constitution = stats.constitution;
            size = stats.size;
            agility = stats.agility;
            stamina = stats.stamina;
            luck = stats.luck;
        } else if (fighterType == GameHelpers.PlayerType.Monster) {
            IMonster.MonsterStats memory stats = monsterContract.getMonster(playerLoadout.playerId);
            strength = stats.strength;
            constitution = stats.constitution;
            size = stats.size;
            agility = stats.agility;
            stamina = stats.stamina;
            luck = stats.luck;
        } else {
            // PlayerCharacter
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerLoadout.playerId);
            strength = stats.strength;
            constitution = stats.constitution;
            size = stats.size;
            agility = stats.agility;
            stamina = stats.stamina;
            luck = stats.luck;
        }

        return IGameEngine.FighterStats({
            playerId: playerLoadout.playerId,
            weapon: attrs.weapon,
            armor: attrs.armor,
            stance: attrs.stance,
            attributes: GameHelpers.Attributes(strength, constitution, size, agility, stamina, luck)
        });
    }

    /// @notice Helper to ensure an address has enough slots for desired player count
    /// @param owner Address to purchase slots for
    /// @param desiredSlots Total number of slots needed
    /// @param contractInstance Player contract instance
    function _ensurePlayerSlots(address owner, uint256 desiredSlots, IPlayer contractInstance) internal {
        require(desiredSlots <= 200, "Cannot exceed MAX_TOTAL_SLOTS");

        uint256 currentSlots = contractInstance.getPlayerSlots(owner);
        if (currentSlots >= desiredSlots) return; // Already have enough slots

        // Calculate how many batches of 5 slots we need to purchase
        uint256 slotsNeeded = desiredSlots - currentSlots;
        uint256 batchesNeeded = (slotsNeeded + 4) / 5; // Round up division

        // Purchase required batches
        for (uint256 i = 0; i < batchesNeeded; i++) {
            vm.startPrank(owner);
            uint256 batchCost = contractInstance.getNextSlotBatchCost(owner);
            vm.deal(owner, batchCost);
            contractInstance.purchasePlayerSlots{value: batchCost}();
            vm.stopPrank();
        }

        // Verify we have enough slots
        assertGe(contractInstance.getPlayerSlots(owner), desiredSlots);
    }

    /// @notice Mints default characters for testing
    /// @dev This creates a standard set of characters with different fighting styles
    function _mintDefaultCharacters() internal {
        // Mint default skin token ID 1
        (uint8 weapon, uint8 armor, uint8 stance, IDefaultPlayer.DefaultPlayerStats memory stats, string memory ipfsCID)
        = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 1);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 1);
        // Create offensive characters
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 2);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 2);
        chars.greatswordOffensive = 2;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getOffensiveTestWarrior(skinIndex, 3);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 3);
        chars.battleaxeOffensive = 3;

        // Create balanced character
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getDefaultWarrior(skinIndex, 4);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 4);
        chars.spearBalanced = 4;

        // Create defensive characters
        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getSwordAndShieldUser(skinIndex, 5);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 5);
        chars.swordAndShieldDefensive = 5;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getRapierAndShieldUser(skinIndex, 6);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 6);
        chars.rapierAndShieldDefensive = 6;

        (weapon, armor, stance, stats, ipfsCID) = DefaultPlayerLibrary.getQuarterstaffUser(skinIndex, 7);
        defaultSkin.mintDefaultPlayerSkin(weapon, armor, stance, stats, ipfsCID, 7);
        chars.quarterstaffDefensive = 7;
    }

    // Helper functions
    function _createPlayerAndFulfillVRF(address owner, bool useSetB) internal returns (uint32) {
        return _createPlayerAndFulfillVRF(owner, playerContract, useSetB);
    }

    function _createPlayerAndExpectVRFFail(address owner, bool useSetB, string memory expectedError) internal {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{
            value: playerContract.createPlayerFeeAmount()
        }(useSetB);
        vm.stopPrank();

        vm.expectRevert(bytes(expectedError));
        _fulfillVRF(requestId, uint256(keccak256(abi.encodePacked("test randomness"))));
    }

    function _createPlayerAndExpectVRFFail(
        address owner,
        bool useSetB,
        string memory expectedError,
        uint256 customRoundId
    ) internal {
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{
            value: playerContract.createPlayerFeeAmount()
        }(useSetB);
        vm.stopPrank();

        bytes memory extraData = "";
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(customRoundId, innerData);

        vm.expectRevert(bytes(expectedError));
        vm.prank(operator);
        playerContract.fulfillRandomness(
            uint256(keccak256(abi.encodePacked("test randomness"))), dataWithRound
        );
    }

    // Helper function for VRF fulfillment
    function _fulfillVRF(uint256 requestId, uint256 randomSeed) internal {
        _fulfillVRF(requestId, randomSeed, address(playerContract));
    }

    function getWeaponName(uint8 weapon) internal view returns (string memory) {
        if (weapon == gameEngine.WEAPON_SWORD_AND_SHIELD()) return "SwordAndShield";
        if (weapon == gameEngine.WEAPON_MACE_AND_SHIELD()) return "MaceAndShield";
        if (weapon == gameEngine.WEAPON_RAPIER_AND_SHIELD()) return "RapierAndShield";
        if (weapon == gameEngine.WEAPON_GREATSWORD()) return "Greatsword";
        if (weapon == gameEngine.WEAPON_BATTLEAXE()) return "Battleaxe";
        if (weapon == gameEngine.WEAPON_QUARTERSTAFF()) return "Quarterstaff";
        if (weapon == gameEngine.WEAPON_SPEAR()) return "Spear";
        return "Unknown";
    }

    function getArmorName(uint8 armor) internal view returns (string memory) {
        if (armor == gameEngine.ARMOR_CLOTH()) return "Cloth";
        if (armor == gameEngine.ARMOR_LEATHER()) return "Leather";
        if (armor == gameEngine.ARMOR_CHAIN()) return "Chain";
        if (armor == gameEngine.ARMOR_PLATE()) return "Plate";
        return "Unknown";
    }

    function getStanceName(uint8 stance) internal view returns (string memory) {
        if (stance == gameEngine.STANCE_DEFENSIVE()) return "Defensive";
        if (stance == gameEngine.STANCE_BALANCED()) return "Balanced";
        if (stance == gameEngine.STANCE_OFFENSIVE()) return "Offensive";
        return "Unknown";
    }
}
