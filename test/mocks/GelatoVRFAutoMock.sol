// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";

// Interface for Gelato VRF Consumer (simplified version for testing)
interface IGelatoVRFConsumer {
    function fulfillRandomness(uint256 randomness, bytes calldata dataWithRound) external;
}

/**
 * @title GelatoVRFAutoMock
 * @notice Automated VRF mock that captures events and provides easy fulfillment
 * @dev This contract automatically tracks VRF requests and provides helper functions for testing
 */
contract GelatoVRFAutoMock {
    struct VRFRequest {
        address consumer;
        uint256 round;
        bytes data;
        bool fulfilled;
        uint256 timestamp;
        bytes32 dataHash;
    }

    // Events
    event VRFRequestCaptured(uint256 indexed requestId, address indexed consumer, uint256 round);
    event VRFRequestFulfilled(uint256 indexed requestId, uint256 randomness);

    // Storage
    mapping(uint256 => VRFRequest) public vrfRequests;
    mapping(address => uint256[]) public consumerRequests; // Track requests per consumer
    uint256 public requestCounter;
    address public operator;
    bool public autoCapture = true;

    // Constants matching GelatoVRFConsumerBase
    uint256 private constant _PERIOD = 3;
    uint256 private constant _GENESIS = 1692803367;

    // Foundry VM interface for pranking
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    constructor(address _operator) {
        operator = _operator;
    }

    /**
     * @notice Captures a VRF request from event data
     * @dev This is called when we detect a RequestedRandomness event
     */
    function captureVRFRequest(address consumer, uint256 round, bytes calldata data) external {
        uint256 requestId = requestCounter++;

        vrfRequests[requestId] = VRFRequest({
            consumer: consumer,
            round: round,
            data: data,
            fulfilled: false,
            timestamp: block.timestamp,
            dataHash: keccak256(data)
        });

        // Track requests per consumer
        consumerRequests[consumer].push(requestId);

        emit VRFRequestCaptured(requestId, consumer, round);
    }

    /**
     * @notice Fulfills a specific VRF request
     * @param requestId The ID of the request to fulfill
     * @param randomness The random value to provide
     */
    function fulfillVRFRequest(uint256 requestId, uint256 randomness) public {
        require(requestId < requestCounter, "Invalid request ID");
        VRFRequest storage request = vrfRequests[requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(request.consumer != address(0), "Request not found");

        // Mark as fulfilled
        request.fulfilled = true;

        // Encode the data with round as GelatoVRFConsumerBase expects
        bytes memory dataWithRound = abi.encode(request.round, request.data);

        // Call the consumer's fulfillRandomness function as the operator
        vm.prank(operator);
        (bool success,) = request.consumer.call(
            abi.encodeWithSignature("fulfillRandomness(uint256,bytes)", randomness, dataWithRound)
        );
        require(success, "VRF fulfillment failed");

        emit VRFRequestFulfilled(requestId, randomness);
    }

    /**
     * @notice Fulfills the latest unfulfilled request for a specific consumer
     * @param consumer The consumer contract address
     * @param randomness The random value to provide
     * @return requestId The ID of the fulfilled request
     */
    function fulfillLatestRequestForConsumer(address consumer, uint256 randomness)
        external
        returns (uint256 requestId)
    {
        uint256[] memory requests = consumerRequests[consumer];
        require(requests.length > 0, "No requests for consumer");

        // Find the latest unfulfilled request for this consumer
        for (uint256 i = requests.length; i > 0; i--) {
            uint256 currentId = requests[i - 1];
            if (!vrfRequests[currentId].fulfilled) {
                fulfillVRFRequest(currentId, randomness);
                return currentId;
            }
        }
        revert("No unfulfilled requests found for consumer");
    }

    /**
     * @notice Fulfills the latest unfulfilled request globally
     * @param randomness The random value to provide
     * @return requestId The ID of the fulfilled request
     */
    function fulfillLatestRequest(uint256 randomness) external returns (uint256 requestId) {
        require(requestCounter > 0, "No requests to fulfill");

        // Find the latest unfulfilled request globally
        for (uint256 i = requestCounter; i > 0; i--) {
            uint256 currentId = i - 1;
            if (!vrfRequests[currentId].fulfilled && vrfRequests[currentId].consumer != address(0)) {
                fulfillVRFRequest(currentId, randomness);
                return currentId;
            }
        }
        revert("No unfulfilled requests found");
    }

    /**
     * @notice Fulfills all unfulfilled requests
     * @param randomness The random value to provide to all requests
     */
    function fulfillAllRequests(uint256 randomness) external {
        for (uint256 i = 0; i < requestCounter; i++) {
            if (!vrfRequests[i].fulfilled && vrfRequests[i].consumer != address(0)) {
                fulfillVRFRequest(i, randomness);
            }
        }
    }

    /**
     * @notice Gets all request IDs for a consumer
     */
    function getConsumerRequests(address consumer) external view returns (uint256[] memory) {
        return consumerRequests[consumer];
    }

    /**
     * @notice Gets the number of unfulfilled requests for a consumer
     */
    function getUnfulfilledRequestCount(address consumer) external view returns (uint256 count) {
        uint256[] memory requests = consumerRequests[consumer];
        for (uint256 i = 0; i < requests.length; i++) {
            if (!vrfRequests[requests[i]].fulfilled) {
                count++;
            }
        }
    }

    /**
     * @notice Gets the latest unfulfilled request ID for a consumer
     */
    function getLatestUnfulfilledRequest(address consumer) external view returns (uint256) {
        uint256[] memory requests = consumerRequests[consumer];
        require(requests.length > 0, "No requests for consumer");

        for (uint256 i = requests.length; i > 0; i--) {
            uint256 currentId = requests[i - 1];
            if (!vrfRequests[currentId].fulfilled) {
                return currentId;
            }
        }
        revert("No unfulfilled requests found for consumer");
    }

    /**
     * @notice Gets request details
     */
    function getRequest(uint256 requestId) external view returns (VRFRequest memory) {
        return vrfRequests[requestId];
    }

    /**
     * @notice Gets the total number of requests
     */
    function getRequestCount() external view returns (uint256) {
        return requestCounter;
    }

    /**
     * @notice Checks if a request is fulfilled
     */
    function isRequestFulfilled(uint256 requestId) external view returns (bool) {
        return vrfRequests[requestId].fulfilled;
    }

    /**
     * @notice Gets the current round number (matches GelatoVRFConsumerBase logic)
     */
    function getCurrentRound() external view returns (uint256 round) {
        uint256 elapsedFromGenesis = block.timestamp - _GENESIS;
        uint256 currentRound = (elapsedFromGenesis / _PERIOD) + 1;

        // Adjust for different chains (mainnet vs others)
        round = block.chainid == 1 ? currentRound + 4 : currentRound + 1;
    }

    /**
     * @notice Sets a new operator
     */
    function setOperator(address newOperator) external {
        operator = newOperator;
    }

    /**
     * @notice Toggles auto-capture mode
     */
    function setAutoCapture(bool _autoCapture) external {
        autoCapture = _autoCapture;
    }

    /**
     * @notice Helper to generate deterministic randomness for testing
     */
    function generateDeterministicRandomness(uint256 seed) external pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, "test_randomness")));
    }

    /**
     * @notice Emergency function to clear all requests (for test cleanup)
     */
    function clearAllRequests() external {
        for (uint256 i = 0; i < requestCounter; i++) {
            delete vrfRequests[i];
        }
        requestCounter = 0;
    }
}
