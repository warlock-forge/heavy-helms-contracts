# TestBase Reference

Complete reference for all helpers in `test/TestBase.sol`.

## Available Contracts (Deployed in setUp)

```solidity
VRFCoordinatorV2_5Mock public vrfMock;
uint256 public subscriptionId;
address public vrfCoordinator;

Player public playerContract;
DefaultPlayer public defaultPlayerContract;
Monster public monsterContract;

DefaultPlayerSkinNFT public defaultSkin;
PlayerSkinRegistry public skinRegistry;
PlayerNameRegistry public nameRegistry;
MonsterNameRegistry public monsterNameRegistry;
MonsterSkinNFT public monsterSkin;

EquipmentRequirements public equipmentRequirements;
GameEngine public gameEngine;
PlayerTickets public playerTickets;
TestPlayerTicketMinter public ticketMinter;

uint32 public defaultSkinIndex;
uint32 public monsterSkinIndex;
```

## VRF Helper Methods

### _createPlayerAndFulfillVRF
```solidity
function _createPlayerAndFulfillVRF(address owner, bool useSetB) internal returns (uint32)
function _createPlayerAndFulfillVRF(address owner, Player contractInstance, bool useSetB) internal returns (uint32)
```
Creates a player via VRF and fulfills the request automatically.
- Records logs internally
- Handles VRF fulfillment
- Extracts and returns the new playerId

**Usage:**
```solidity
uint32 playerId = _createPlayerAndFulfillVRF(PLAYER_ONE, false);
```

### _createPlayerRequest
```solidity
function _createPlayerRequest(address owner, IPlayer contractInstance, bool useSetB) internal returns (uint256)
```
Creates a VRF request WITHOUT fulfillment. Useful for testing VRF mechanics.
- Returns the requestId
- Does NOT fulfill - call `_fulfillVRFRequest()` separately

### _fulfillVRFRequest
```solidity
function _fulfillVRFRequest(address gameContract) internal
```
Fulfills a pending VRF request.
- **REQUIRES** `vm.recordLogs()` called before the VRF request
- Extracts requestId from `RandomWordsRequested` event (sig: `0xeb0e3652...`)
- Calls VRF mock to fulfill

**Usage:**
```solidity
vm.recordLogs();  // MUST be before request
uint256 requestId = game.someVRFRequest();
_fulfillVRFRequest(address(game));
```

### _getPlayerIdFromLogs
```solidity
function _getPlayerIdFromLogs(address owner, uint256 requestId) internal returns (uint32)
```
Extracts playerId from `PlayerCreationComplete` event in recorded logs.

### _fulfillVRF (Low-level)
```solidity
function _fulfillVRF(uint256 requestId, uint256 randomSeed, address vrfConsumer) internal
```
Directly fulfills VRF with specific seed. Used internally.

## Loadout & Fighter Helpers

### _createLoadout
```solidity
function _createLoadout(uint32 fighterId) internal view returns (Fighter.PlayerLoadout memory)
```
Creates a loadout for any fighter type. Automatically detects type from ID range and fetches current skin/stance.

**Usage:**
```solidity
Fighter.PlayerLoadout memory loadout = _createLoadout(PLAYER_ONE_ID);
```

### _convertToFighterStats
```solidity
function _convertToFighterStats(Fighter.PlayerLoadout memory loadout) internal view returns (IGameEngine.FighterStats memory)
```
Converts loadout to FighterStats for direct GameEngine testing.
- Fetches weapon/armor from skin attributes
- Handles default player/monster specialization (255)

### _getFighterType
```solidity
function _getFighterType(uint32 playerId) internal pure returns (Fighter.FighterType)
```
Returns fighter type based on ID range:
- 1-2000: DEFAULT_PLAYER
- 2001-10000: MONSTER
- 10001+: PLAYER

### _getFighterContract
```solidity
function _getFighterContract(uint32 playerId) internal view returns (Fighter)
```
Returns the correct Fighter contract for a player ID.

## Assertion Helpers

### _assertStatRanges
```solidity
function _assertStatRanges(IPlayer.PlayerStats memory stats) internal pure virtual
```
Validates all stats are in 3-21 range.

### _assertPlayerState
```solidity
function _assertPlayerState(Player contractInstance, uint32 playerId, address expectedOwner, bool shouldExist) internal
```
Validates player ownership and existence.

### _assertBalances
```solidity
function _assertBalances(address account, uint256 expectedBalance, string memory message) internal view
```
Validates ETH balance.

### _assertValidCombatResult
```solidity
function _assertValidCombatResult(uint16 version, IGameEngine.WinCondition condition, IGameEngine.CombatAction[] memory actions) internal pure
```
Validates combat result structure.

### _assertValidCombatEvent
```solidity
function _assertValidCombatEvent(bytes32 player1Data, bytes32 player2Data) internal
```
Validates CombatResult event data from logs.

## Ticket Minting Helpers

All use the `ticketMinter` contract which has full permissions:

```solidity
function _mintTickets(address to, uint256 ticketType, uint256 amount) internal
function _mintCreatePlayerTickets(address to, uint256 amount) internal
function _mintPlayerSlotTickets(address to, uint256 amount) internal
function _mintWeaponSpecTickets(address to, uint256 amount) internal
function _mintArmorSpecTickets(address to, uint256 amount) internal
function _mintDuelTickets(address to, uint256 amount) internal
function _mintDailyResetTickets(address to, uint256 amount) internal
function _mintAttributeSwapTickets(address to, uint256 amount) internal
function _mintNameChangeNFT(address to, uint256 seed) internal returns (uint256 tokenId)
```

**Usage:**
```solidity
_mintDuelTickets(PLAYER_ONE, 10);  // Mint 10 duel tickets
```

## Slot Management

### _ensurePlayerSlots
```solidity
function _ensurePlayerSlots(address owner, uint256 desiredSlots, IPlayer contractInstance) internal
```
Purchases slots until owner has at least `desiredSlots`. Max 100.

## Fixture Creation

### _mintDefaultCharacters
```solidity
function _mintDefaultCharacters() internal
```
Creates all default players (IDs 1-2000) via DefaultPlayerLibrary.
Called automatically in setUp().

### _mintMonsters
```solidity
function _mintMonsters() internal
```
Creates test monsters:
- 2001: Easy Goblin (DUAL_CLUBS, 62-71 attr points)
- 2002: Normal Undead (DUAL_DAGGERS, 72-81 attr points)
- 2003: Hard Demon (ARMING_SWORD_KITE, 82-91 attr points)
Called automatically in setUp().

## Utility Helpers

### _generateGameSeed
```solidity
function _generateGameSeed() internal view returns (uint256)
```
Returns deterministic seed from block data.

### _isDefensiveResult
```solidity
function _isDefensiveResult(IGameEngine.CombatResultType result) internal pure returns (bool)
```
Checks if combat result is defensive action (MISS, HIT, PARRY, BLOCK, DODGE, COUNTER, etc.)

### _registerSkin
```solidity
function _registerSkin(address skinContract) internal returns (uint32)
```
Registers a new skin NFT contract with the registry.

### Name Helpers
```solidity
function getWeaponName(uint8 weapon) internal view returns (string memory)
function getArmorName(uint8 armor) internal view returns (string memory)
function getStanceName(uint8 stance) internal view returns (string memory)
```
Convert enum values to readable strings for logging.

## Modifier

### skipInCI
```solidity
modifier skipInCI()
```
Skips test execution if `CI` environment variable is set.

**Usage:**
```solidity
function testLongRunning() public skipInCI {
    // Only runs locally
}
```

## VRF Mock Configuration

Set up in setUp():
```solidity
vrfMock = new VRFCoordinatorV2_5Mock(
    100000000000000000,  // 0.1 LINK base fee
    1000000000,          // 1 gwei gas price
    4000000000000000000  // 4 LINK per ETH
);
subscriptionId = vrfMock.createSubscription();
vrfMock.fundSubscriptionWithNative{value: 100 ether}(subscriptionId);
```

Add consumers manually for game contracts:
```solidity
vrfMock.addConsumer(subscriptionId, address(gameContract));
```

## Timestamp Setup

TestBase sets timestamp BEFORE Player deployment:
```solidity
vm.warp(1692803367 + 1000);
```
This ensures reproducible player creation timestamps.
