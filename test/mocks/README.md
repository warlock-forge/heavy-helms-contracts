# VRF Mock System

This directory contains the VRF mock system for testing Gelato VRF functionality without external dependencies.

## Overview

The VRF mock system replaces the previous "fake" VRF implementation with a sophisticated mock that simulates the complete VRF request/fulfillment lifecycle. This enables comprehensive testing of VRF-dependent functionality in a deterministic, controllable environment.

## Components

### 1. GelatoVRFAutoMock.sol
The core mock contract that simulates Gelato VRF behavior:
- **Automatic Request Capture**: Listens for VRF request events and automatically captures them
- **Flexible Fulfillment**: Supports manual, automatic, and batch fulfillment modes
- **Request Tracking**: Maintains complete state for all VRF requests per consumer
- **Deterministic Randomness**: Generates reproducible randomness for testing
- **State Inspection**: Provides comprehensive request inspection capabilities

### 2. Enhanced TestBase.sol
Extended base test contract with VRF mock integration:
- **Mode Switching**: Toggle between mock and legacy VRF modes
- **Helper Functions**: Simplified VRF request creation and fulfillment
- **Event Processing**: Automatic capture of VRF requests from transaction logs
- **Batch Operations**: Fulfill multiple pending requests at once

### 3. VRFMockExample.t.sol
Comprehensive examples demonstrating VRF mock usage:
- Basic player creation with automatic VRF fulfillment
- Manual VRF request handling and inspection
- Multiple request scenarios and batch fulfillment
- Deterministic randomness testing
- Edge case and error condition testing

## Key Features

### Before: "Fake" VRF System
```solidity
// Manual, hardcoded approach
function testCreatePlayer() public {
    uint256 requestId = _createPlayerRequest(player, false);
    _fulfillVRF(requestId, 12345, address(playerContract)); // Hardcoded randomness
}
```

### After: VRF Mock System
```solidity
// Automatic, event-driven approach
function testCreatePlayer() public {
    _setVRFMockMode(true);
    uint32 playerId = _createPlayerAndFulfillVRFWithMock(player, playerContract, false);
    // VRF request automatically captured and fulfilled
}
```

## Usage Examples

### Basic Usage
```solidity
function testBasicVRF() public {
    _setVRFMockMode(true);
    
    // Create player with automatic VRF fulfillment
    uint32 playerId = _createPlayerAndFulfillVRFWithMock(
        playerAddress, 
        playerContract, 
        false // useSetB
    );
    
    // Player is created and ready to use
    assertTrue(playerId > 0);
}
```

### Manual Request Handling
```solidity
function testManualVRF() public {
    _setVRFMockMode(true);
    GelatoVRFAutoMock vrfMock = _getVRFMock();
    
    vm.recordLogs();
    _createPlayerRequest(playerAddress, playerContract, false);
    _captureVRFRequestsFromLogs();
    
    // Fulfill with custom randomness
    vrfMock.fulfillLatestRequestForConsumer(
        address(playerContract), 
        customRandomness
    );
}
```

### Multiple Requests
```solidity
function testMultipleVRF() public {
    _setVRFMockMode(true);
    
    vm.recordLogs();
    _createPlayerRequest(player1, playerContract, false);
    _createPlayerRequest(player2, playerContract, true);
    _createPlayerRequest(player3, playerContract, false);
    _captureVRFRequestsFromLogs();
    
    // Fulfill all at once
    _fulfillAllPendingVRFRequests();
}
```

### Request Inspection
```solidity
function testInspection() public {
    _setVRFMockMode(true);
    GelatoVRFAutoMock vrfMock = _getVRFMock();
    
    // ... create requests ...
    
    // Inspect request details
    GelatoVRFAutoMock.VRFRequest memory request = vrfMock.getRequest(0);
    assertEq(request.consumer, address(playerContract));
    assertFalse(request.fulfilled);
    
    // Get consumer-specific requests
    uint256[] memory requests = vrfMock.getConsumerRequests(address(playerContract));
}
```

## Migration Guide

### From Legacy VRF Testing
1. **Enable Mock Mode**: Call `_setVRFMockMode(true)` in your test setup
2. **Replace Manual Calls**: Use `_createPlayerAndFulfillVRFWithMock()` instead of manual VRF fulfillment
3. **Event Capture**: Use `vm.recordLogs()` and `_captureVRFRequestsFromLogs()` for manual handling
4. **Batch Operations**: Use `_fulfillAllPendingVRFRequests()` for multiple requests

### Key Helper Functions
- `_setVRFMockMode(bool enabled)`: Toggle between mock and legacy modes
- `_getVRFMock()`: Get the VRF mock instance
- `_createPlayerAndFulfillVRFWithMock(address, Player, bool)`: Create player with auto-VRF
- `_captureVRFRequestsFromLogs()`: Process VRF events from transaction logs
- `_fulfillAllPendingVRFRequests()`: Batch fulfill all pending requests
- `_getPendingVRFRequestCount(address)`: Get pending request count for consumer

## Benefits

### 1. **No External Dependencies**
- Eliminates need for Gelato web3 functions
- No drand network dependency
- Fully self-contained testing environment

### 2. **Event-Driven Testing**
- Simulates real VRF request lifecycle
- Automatic request capture from events
- Realistic testing scenarios

### 3. **Deterministic Results**
- Reproducible test outcomes
- Consistent randomness generation
- Reliable CI/CD pipeline execution

### 4. **Advanced Scenarios**
- Multiple request handling
- Batch fulfillment operations
- Error condition testing
- Request state inspection

### 5. **Backward Compatibility**
- Legacy VRF mode still available
- Gradual migration path
- Existing tests continue to work

## Testing

Run the VRF mock examples:
```bash
forge test --match-contract VRFMockExample -vv
```

Run all player tests with VRF mock:
```bash
forge test --match-path "test/fighters/Player.t.sol" -v
```

## Implementation Status

✅ **Complete**: Core VRF mock system
✅ **Complete**: TestBase integration
✅ **Complete**: Example tests and documentation
✅ **Complete**: Backward compatibility
✅ **Complete**: Event-driven request capture
✅ **Complete**: Batch fulfillment operations
✅ **Complete**: Request inspection capabilities

## Future Enhancements

- **Gas Usage Simulation**: Mock gas costs for VRF operations
- **Failure Simulation**: Test VRF request failures and timeouts
- **Performance Metrics**: Track VRF request/fulfillment timing
- **Advanced Randomness**: Support for different randomness distributions

## Troubleshooting

### Common Issues

1. **No VRF Requests Captured**
   - Ensure `vm.recordLogs()` is called BEFORE creating requests
   - Call `_captureVRFRequestsFromLogs()` after request creation

2. **Request Not Found**
   - Verify the consumer address matches the contract making requests
   - Check that requests were properly captured from logs

3. **Legacy Mode Fallback**
   - Use `_setVRFMockMode(false)` to switch to legacy mode
   - Legacy functions still available for backward compatibility

### Debug Functions
```solidity
// Check mock mode status
bool isMockMode = _isVRFMockMode();

// Get request count
uint256 count = _getVRFMock().getRequestCount();

// Get pending requests for consumer
uint256 pending = _getPendingVRFRequestCount(address(consumer));
```

This VRF mock system provides a robust foundation for testing VRF-dependent functionality while maintaining simplicity and reliability. 