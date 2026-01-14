# Game Mode Test Patterns

Specific patterns for each game mode's test infrastructure.

## Player.t.sol Patterns

### setUp() Minimal
```solidity
function setUp() public override {
    super.setUp();
    PLAYER_ONE = address(0x1111);
    PLAYER_TWO = address(0x2222);
}
```

No game contract needed - tests Player directly. VRF consumer already added in TestBase.

### Player Creation Flow
```solidity
// Full flow with ID extraction
uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);

// Manual flow for testing pending state
vm.recordLogs();
uint256 requestId = _createPlayerRequest(PLAYER_ONE, playerContract, false);
_fulfillVRFRequest(address(playerContract));
uint32 playerId = _getPlayerIdFromLogs(PLAYER_ONE, requestId);
```

### Stat Distribution Testing
```solidity
function test_statDistribution() public skipInCI {
    uint256 maxStats;
    uint256 highStats;
    uint256 medStats;
    uint256 lowStats;

    for (uint i = 0; i < 100; i++) {
        uint32 id = _createPlayerAndFulfillVRF(address(uint160(i + 1000)), false);
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(id);

        // Count each stat's range
        uint8[6] memory attrs = [
            stats.attributes.strength,
            stats.attributes.constitution,
            stats.attributes.size,
            stats.attributes.agility,
            stats.attributes.stamina,
            stats.attributes.luck
        ];

        for (uint j = 0; j < 6; j++) {
            if (attrs[j] >= 19) maxStats++;
            else if (attrs[j] >= 16) highStats++;
            else if (attrs[j] >= 13) medStats++;
            else lowStats++;
        }
    }

    // Verify distribution
    assertTrue(maxStats * 100 / 600 < 20, "Too many max stats");
    assertTrue(lowStats * 100 / 600 > 40, "Too few low stats");
}
```

### Skin Equipment Testing
```solidity
function testEquipSkin() public {
    uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
    IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);

    // Check if player meets requirements
    bool meetsAgiReq = stats.attributes.agility >= 8;
    bool meetsStrReq = stats.attributes.strength >= 5;

    if (meetsAgiReq && meetsStrReq) {
        vm.prank(PLAYER_ONE);
        playerContract.equipSkin(
            playerId,
            Fighter.SkinInfo({skinIndex: someSkinIndex, skinTokenId: tokenId})
        );
    }
}
```

---

## DuelGame.t.sol Patterns

### setUp() Full
```solidity
function setUp() public override {
    super.setUp();

    game = new DuelGame(
        address(gameEngine),
        payable(address(playerContract)),
        vrfCoordinator,
        subscriptionId,
        testKeyHash,
        address(playerTickets)
    );

    // VRF consumer registration
    vrfMock.addConsumer(subscriptionId, address(game));

    // Permissions (record only - duels don't affect career)
    IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
        record: true,
        retire: false,
        immortal: false,
        experience: false
    });
    playerContract.setGameContractPermission(address(game), perms);

    // Players
    PLAYER_ONE = address(0xdF);
    PLAYER_TWO = address(0xeF);
    PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
    PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);

    // Funding
    vm.deal(PLAYER_ONE, 100 ether);
    vm.deal(PLAYER_TWO, 100 ether);

    // Tickets and approvals
    _mintDuelTickets(PLAYER_ONE, 10);
    _mintDuelTickets(PLAYER_TWO, 10);

    vm.prank(PLAYER_ONE);
    playerTickets.setApprovalForAll(address(game), true);
    vm.prank(PLAYER_TWO);
    playerTickets.setApprovalForAll(address(game), true);
}
```

### Challenge State Machine
```solidity
function testChallengeStateMachine() public {
    Fighter.PlayerLoadout memory challengerLoadout = _createLoadout(PLAYER_ONE_ID);
    Fighter.PlayerLoadout memory defenderLoadout = _createLoadout(PLAYER_TWO_ID);

    // CREATE -> OPEN
    vm.prank(PLAYER_ONE);
    uint256 challengeId = game.initiateChallengeWithTicket(challengerLoadout, PLAYER_TWO_ID);

    assertTrue(game.isChallengeActive(challengeId));
    assertFalse(game.isChallengePending(challengeId));

    // ACCEPT -> PENDING (VRF requested)
    vm.recordLogs();
    vm.prank(PLAYER_TWO);
    game.acceptChallenge(challengeId, defenderLoadout);

    assertFalse(game.isChallengeActive(challengeId));
    assertTrue(game.isChallengePending(challengeId));

    // FULFILL VRF -> COMPLETED
    _fulfillVRFRequest(address(game));

    assertFalse(game.isChallengeActive(challengeId));
    assertFalse(game.isChallengePending(challengeId));
}
```

### Custom Loadout Override Test
```solidity
function testLoadoutOverridesEquipped() public {
    Fighter.PlayerLoadout memory challengerLoadout = Fighter.PlayerLoadout({
        playerId: PLAYER_ONE_ID,
        skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: 17}),
        stance: 2  // Aggressive
    });

    Fighter.PlayerLoadout memory defenderLoadout = Fighter.PlayerLoadout({
        playerId: PLAYER_TWO_ID,
        skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: 1}),
        stance: 0  // Defensive
    });

    // Challenge uses these loadouts, not equipped gear
    vm.prank(PLAYER_ONE);
    uint256 challengeId = game.initiateChallengeWithTicket(challengerLoadout, PLAYER_TWO_ID);

    // Verify stored loadout
    (,, Fighter.PlayerLoadout memory stored,,,) = game.getChallenge(challengeId);
    assertEq(stored.stance, 2);
}
```

---

## GauntletGame.t.sol Patterns

### setUp() Full
```solidity
function setUp() public override {
    super.setUp();

    game = new GauntletGame(
        address(gameEngine),
        payable(address(playerContract)),
        address(defaultPlayerContract),
        GauntletGame.LevelBracket.LEVELS_1_TO_4,
        address(playerTickets)
    );

    // Transfer default player ownership for substitution
    defaultPlayerContract.transferOwnership(address(game));

    // Permissions (record + experience for XP rewards)
    IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
        record: true,
        retire: false,
        immortal: false,
        experience: true
    });
    playerContract.setGameContractPermission(address(game), perms);

    // Players
    PLAYER_ONE = address(0x1001);
    PLAYER_TWO = address(0x1002);
    PLAYER_THREE = address(0x1003);
    PLAYER_FOUR = address(0x1004);

    PLAYER_ONE_ID = _createPlayerAndFulfillVRF(PLAYER_ONE, playerContract, false);
    PLAYER_TWO_ID = _createPlayerAndFulfillVRF(PLAYER_TWO, playerContract, false);
    PLAYER_THREE_ID = _createPlayerAndFulfillVRF(PLAYER_THREE, playerContract, false);
    PLAYER_FOUR_ID = _createPlayerAndFulfillVRF(PLAYER_FOUR, playerContract, false);

    // Funding
    vm.deal(PLAYER_ONE, 100 ether);
    vm.deal(PLAYER_TWO, 100 ether);
    vm.deal(PLAYER_THREE, 100 ether);
    vm.deal(PLAYER_FOUR, 100 ether);

    // Configure for testing
    game.setMinTimeBetweenGauntlets(0);
    game.setGameEnabled(false);
    game.setGauntletSize(4);
    game.setGameEnabled(true);
}
```

### Three-Phase Pattern
```solidity
function testCommitRevealFlow() public {
    // Queue all players
    _queuePlayer(PLAYER_ONE, PLAYER_ONE_ID);
    _queuePlayer(PLAYER_TWO, PLAYER_TWO_ID);
    _queuePlayer(PLAYER_THREE, PLAYER_THREE_ID);
    _queuePlayer(PLAYER_FOUR, PLAYER_FOUR_ID);

    assertEq(game.getQueueSize(), 4);

    // PHASE 1: COMMIT
    game.tryStartGauntlet();
    (bool exists, uint256 selectionBlock,,,,) = game.getPendingGauntletInfo();
    assertTrue(exists);

    // PHASE 2: SELECT
    vm.roll(selectionBlock + 1);
    vm.prevrandao(bytes32(uint256(12345)));
    game.tryStartGauntlet();

    (,, uint256 tournamentBlock,,,) = game.getPendingGauntletInfo();

    // PHASE 3: EXECUTE
    vm.roll(tournamentBlock + 1);
    vm.prevrandao(bytes32(uint256(67890)));
    game.tryStartGauntlet();

    // Verify completion
    GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
    assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED));
    assertEq(game.getQueueSize(), 0);
}

function _queuePlayer(address player, uint32 playerId) internal {
    Fighter.PlayerLoadout memory loadout = _createLoadout(playerId);
    vm.prank(player);
    game.queueForGauntlet(loadout);
}
```

### Player Status Transitions
```solidity
function testPlayerStatusTransitions() public {
    // NONE -> QUEUED
    assertEq(uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.NONE));

    _queuePlayer(PLAYER_ONE, PLAYER_ONE_ID);
    assertEq(uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.QUEUED));

    // QUEUED -> IN_TOURNAMENT (after selection)
    // ... fill queue, run phases 1-2 ...
    assertEq(uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.IN_TOURNAMENT));

    // IN_TOURNAMENT -> NONE (after execution)
    // ... run phase 3 ...
    assertEq(uint8(game.playerStatus(PLAYER_ONE_ID)), uint8(GauntletGame.PlayerStatus.NONE));
}
```

### Bracket Validation
```solidity
function testBracketValidation() public {
    // Level 1-4 bracket accepts levels 1-4
    // Player starts at level 1
    vm.prank(PLAYER_ONE);
    game.queueForGauntlet(loadout);  // Success

    // Level up to 5
    _levelUpPlayer(PLAYER_TWO_ID, 4);  // 1 -> 5

    vm.prank(PLAYER_TWO);
    vm.expectRevert(
        abi.encodeWithSignature("PlayerNotInBracket(uint8,uint8)", 5, uint8(GauntletGame.LevelBracket.LEVELS_1_TO_4))
    );
    game.queueForGauntlet(loadout);  // Fails - wrong bracket
}

function _levelUpPlayer(uint32 playerId, uint256 levels) internal {
    for (uint256 i = 0; i < levels; i++) {
        IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerId);
        uint16 xpNeeded = playerContract.getXPRequiredForLevel(stats.level + 1) - stats.currentXP;
        playerContract.awardExperience(playerId, xpNeeded);
    }
}
```

### Retired Player Substitution
```solidity
function testRetiredPlayerSubstitution() public {
    // Queue and run phases 1-2
    // ...

    // Player retires mid-tournament
    vm.prank(PLAYER_ONE);
    playerContract.retireOwnPlayer(PLAYER_ONE_ID);

    // Phase 3 should substitute with default NPC
    vm.roll(tournamentBlock + 1);
    game.tryStartGauntlet();

    // Tournament completes successfully
    GauntletGame.Gauntlet memory gauntlet = game.getGauntletData(0);
    assertEq(uint8(gauntlet.state), uint8(GauntletGame.GauntletState.COMPLETED));
}
```

---

## MonsterBattleGame.t.sol Patterns

### Trophy System Setup
```solidity
function setUp() public override {
    super.setUp();

    game = new MonsterBattleGame(
        address(gameEngine),
        payable(address(playerContract)),
        address(monsterContract),
        vrfCoordinator,
        subscriptionId,
        testKeyHash,
        address(playerTickets)
    );

    vrfMock.addConsumer(subscriptionId, address(game));

    // Create trophy NFTs for each difficulty
    _setupTrophySystem();

    // Register monsters with difficulty tiers
    game.addNewMonsterBatch(goblinMonsters, MonsterBattleGame.Difficulty.EASY);
    game.addNewMonsterBatch(undeadMonsters, MonsterBattleGame.Difficulty.NORMAL);
    game.addNewMonsterBatch(demonMonsters, MonsterBattleGame.Difficulty.HARD);
}

function _setupTrophySystem() internal {
    goblinTrophy = new MockTrophyNFT("Goblin", "GTR", address(game));
    undeadTrophy = new MockTrophyNFT("Undead", "UTR", address(game));
    demonTrophy = new MockTrophyNFT("Demon", "DTR", address(game));

    game.setTrophyNFT(MonsterBattleGame.Difficulty.EASY, address(goblinTrophy));
    game.setTrophyNFT(MonsterBattleGame.Difficulty.NORMAL, address(undeadTrophy));
    game.setTrophyNFT(MonsterBattleGame.Difficulty.HARD, address(demonTrophy));
}
```

### Battle Flow with Trophy
```solidity
function testMonsterBattleWithTrophy() public {
    Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);

    // Start battle
    vm.recordLogs();
    vm.prank(PLAYER_ONE);
    game.startBattle{value: battleFee}(loadout, MonsterBattleGame.Difficulty.EASY);

    _fulfillVRFRequest(address(game));

    // Check if player won (trophy minted)
    uint256 trophyBalance = goblinTrophy.balanceOf(PLAYER_ONE);
    // Note: May or may not have trophy depending on combat result
}
```

---

## PracticeGame.t.sol Patterns

### No VRF Needed
```solidity
function setUp() public override {
    super.setUp();

    game = new PracticeGame(
        address(gameEngine),
        payable(address(playerContract)),
        address(defaultPlayerContract)
    );

    // No VRF - uses default players
    // No tickets needed
}

function testPracticeMatch() public {
    // Use default player IDs (1-2000)
    Fighter.PlayerLoadout memory playerLoadout = _createLoadout(PLAYER_ONE_ID);  // User player
    Fighter.PlayerLoadout memory npcLoadout = _createLoadout(1);  // Default player #1

    vm.prank(PLAYER_ONE);
    game.fight(playerLoadout, npcLoadout);

    // No VRF fulfillment needed - deterministic combat
}
```

---

## Common Helpers Across Games

### Standard Loadout Creation
```solidity
Fighter.PlayerLoadout memory loadout = Fighter.PlayerLoadout({
    playerId: PLAYER_ONE_ID,
    skin: Fighter.SkinInfo({skinIndex: defaultSkinIndex, skinTokenId: 1}),
    stance: 1  // BALANCED (0=DEFENSIVE, 1=BALANCED, 2=OFFENSIVE)
});
```

### Permission Setup Pattern
```solidity
IPlayer.GamePermissions memory perms = IPlayer.GamePermissions({
    record: true,       // Can record wins/losses/kills
    retire: false,      // Can forcibly retire players
    immortal: false,    // Can make players immortal
    experience: true    // Can award XP
});
playerContract.setGameContractPermission(address(game), perms);
```

### Ticket Approval Pattern
```solidity
_mintDuelTickets(player, 10);
vm.prank(player);
playerTickets.setApprovalForAll(address(game), true);
```
