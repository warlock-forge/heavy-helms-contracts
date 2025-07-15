// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "../TestBase.sol";

/**
 * @title VRFMockExample
 * @notice Example test demonstrating the new VRF mock system usage
 * @dev This shows how to properly test Gelato VRF functionality
 */
contract VRFMockExample is TestBase {
    address public testPlayer = address(0x123);

    function setUp() public override {
        super.setUp();
        // The VRF mock is automatically initialized in TestBase
    }

    /**
     * @notice Example: Basic VRF mock usage for player creation
     */
    function testVRFMock_BasicPlayerCreation() public {
        // Ensure we're using the VRF mock system
        _setVRFMockMode(true);

        // Create a player using the enhanced mock system
        uint32 playerId = _createPlayerAndFulfillVRFWithMock(testPlayer, playerContract, false);

        // Verify the player was created successfully
        assertTrue(playerId > 0, "Player should be created");
        assertEq(playerContract.getPlayerOwner(playerId), testPlayer, "Player owner should match");

        // Verify VRF request was handled
        assertEq(_getPendingVRFRequestCount(address(playerContract)), 0, "No pending VRF requests");
    }

    /**
     * @notice Example: Manual VRF request handling
     */
    function testVRFMock_ManualRequestHandling() public {
        _setVRFMockMode(true);
        GelatoVRFAutoMock vrfMock = _getVRFMock();

        // Step 1: Start recording logs to capture VRF events
        vm.recordLogs();

        // Step 2: Create a player request (without auto-fulfillment)
        _createPlayerRequest(testPlayer, playerContract, false);

        // Step 3: Capture VRF requests from the logs
        _captureVRFRequestsFromLogs();

        // Step 4: Verify the request was captured
        assertEq(vrfMock.getRequestCount(), 1, "Should have 1 VRF request");
        assertEq(_getPendingVRFRequestCount(address(playerContract)), 1, "Should have 1 pending request");

        // Step 5: Manually fulfill with custom randomness
        uint256 customRandomness = 12345;
        uint256 fulfilledRequestId = vrfMock.fulfillLatestRequestForConsumer(address(playerContract), customRandomness);

        // Step 6: Verify fulfillment
        assertEq(fulfilledRequestId, 0, "Should fulfill request ID 0");
        assertTrue(vrfMock.isRequestFulfilled(0), "Request should be fulfilled");
        assertEq(_getPendingVRFRequestCount(address(playerContract)), 0, "No pending requests");
    }

    /**
     * @notice Example: Testing multiple VRF requests
     */
    function testVRFMock_MultipleRequests() public {
        _setVRFMockMode(true);
        GelatoVRFAutoMock vrfMock = _getVRFMock();

        address player1 = address(0x111);
        address player2 = address(0x222);
        address player3 = address(0x333);

        // Start recording logs before creating requests
        vm.recordLogs();

        // Create multiple player requests
        _createPlayerRequest(player1, playerContract, false);
        _createPlayerRequest(player2, playerContract, true);
        _createPlayerRequest(player3, playerContract, false);

        // Capture all VRF requests
        _captureVRFRequestsFromLogs();

        // Verify all requests were captured
        assertEq(vrfMock.getRequestCount(), 3, "Should have 3 VRF requests");
        assertEq(_getPendingVRFRequestCount(address(playerContract)), 3, "Should have 3 pending requests");

        // Fulfill all requests at once
        _fulfillAllPendingVRFRequests();

        // Verify all fulfilled
        assertEq(_getPendingVRFRequestCount(address(playerContract)), 0, "No pending requests");
        assertTrue(vrfMock.isRequestFulfilled(0), "Request 0 fulfilled");
        assertTrue(vrfMock.isRequestFulfilled(1), "Request 1 fulfilled");
        assertTrue(vrfMock.isRequestFulfilled(2), "Request 2 fulfilled");
    }

    /**
     * @notice Example: Testing deterministic randomness
     */
    function testVRFMock_DeterministicRandomness() public {
        _setVRFMockMode(true);
        GelatoVRFAutoMock vrfMock = _getVRFMock();

        // Generate deterministic randomness
        uint256 seed = 42;
        uint256 randomness1 = vrfMock.generateDeterministicRandomness(seed);
        uint256 randomness2 = vrfMock.generateDeterministicRandomness(seed);

        // Should be deterministic (same seed = same result)
        assertEq(randomness1, randomness2, "Deterministic randomness should be consistent");

        // Different seed should give different result
        uint256 randomness3 = vrfMock.generateDeterministicRandomness(seed + 1);
        assertTrue(randomness1 != randomness3, "Different seeds should give different randomness");
    }

    /**
     * @notice Example: Testing fallback to legacy mode
     */
    function testVRFMock_LegacyFallback() public {
        // Switch to legacy mode
        _setVRFMockMode(false);

        // Create a player using legacy VRF fulfillment
        uint32 playerId = _createPlayerAndFulfillVRF(testPlayer, false);

        // Verify the player was created successfully
        assertTrue(playerId > 0, "Player should be created with legacy mode");
        assertEq(playerContract.getPlayerOwner(playerId), testPlayer, "Player owner should match");
    }

    /**
     * @notice Example: Testing VRF request inspection
     */
    function testVRFMock_RequestInspection() public {
        _setVRFMockMode(true);
        GelatoVRFAutoMock vrfMock = _getVRFMock();

        // Start recording logs BEFORE creating the request
        vm.recordLogs();

        // Create a request
        _createPlayerRequest(testPlayer, playerContract, false);

        // Capture VRF requests from the logs
        _captureVRFRequestsFromLogs();

        // Inspect the request details
        GelatoVRFAutoMock.VRFRequest memory request = vrfMock.getRequest(0);
        assertEq(request.consumer, address(playerContract), "Consumer should match");
        assertFalse(request.fulfilled, "Request should not be fulfilled yet");
        assertTrue(request.timestamp > 0, "Timestamp should be set");

        // Get consumer-specific requests
        uint256[] memory consumerRequests = vrfMock.getConsumerRequests(address(playerContract));
        assertEq(consumerRequests.length, 1, "Should have 1 request for consumer");
        assertEq(consumerRequests[0], 0, "First request should be ID 0");
    }

    /**
     * @notice Example: Testing edge cases
     */
    function testVRFMock_EdgeCases() public {
        _setVRFMockMode(true);
        GelatoVRFAutoMock vrfMock = _getVRFMock();

        // Test fulfilling non-existent request
        vm.expectRevert("Invalid request ID");
        vrfMock.fulfillVRFRequest(999, 12345);

        // Test getting requests for consumer with no requests
        vm.expectRevert("No requests for consumer");
        vrfMock.getLatestUnfulfilledRequest(address(0x999));

        // Test fulfilling when no requests exist
        vm.expectRevert("No requests to fulfill");
        vrfMock.fulfillLatestRequest(12345);

        // Test cleanup
        vrfMock.clearAllRequests();
        assertEq(vrfMock.getRequestCount(), 0, "Should have no requests after cleanup");
    }
}
