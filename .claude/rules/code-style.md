---
paths: src/**/*.sol, test/**/*.sol, script/**/*.sol
---

# Heavy Helms Code Style Guide

## File Header Pattern

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;
```

## Section Dividers

Total width is 66 characters (// + 62 equal signs + //)

```solidity
//==============================================================//
//                          SECTION_NAME                        //
//==============================================================//
```

## Section Order (maintain this strict ordering)

1. IMPORTS
2. INTERFACES (if needed)
3. CUSTOM ERRORS
4. Contract declaration with title block
5. ENUMS
6. STRUCTS
7. STATE VARIABLES
8. EVENTS
9. MODIFIERS
10. CONSTRUCTOR
11. EXTERNAL FUNCTIONS (main functions)
12. ADMIN FUNCTIONS
13. INTERNAL FUNCTIONS
14. VIRTUAL FUNCTIONS (for abstract contracts)
15. PRIVATE FUNCTIONS
16. FALLBACK FUNCTIONS (if needed)

## Contract-Level Documentation

```solidity
//==============================================================//
//                         HEAVY HELMS                          //
//                         CONTRACT_NAME                        //
//==============================================================//
/// @title [Contract Title]
/// @notice [High-level description of what the contract does]
/// @dev [Technical implementation details]
```

## Function Documentation

- Complete NatSpec documentation for all public/external functions
- `@notice` for user-facing description
- `@dev` for technical details
- `@param` for all parameters
- `@return` for return values

## State Variable Documentation

```solidity
// --- Section Header ---
/// @notice Brief description of the variable
/// @dev Technical details if needed
```

## Variable Naming

- State variables: `camelCase` (e.g., `currentGauntletSize`, `playerStatus`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `DEFAULT_PLAYER_END`, `CLEAR_BATCH_SIZE`)
- Private/internal with underscore prefix: `_variableName`
- Mappings: descriptive names (e.g., `playerIndexInQueue`, `requestToChallengeId`)

## Function Naming

- External/public: `camelCase` (e.g., `queueForGauntlet`, `tryStartGauntlet`)
- Internal/private with underscore: `_functionName` (e.g., `_commitQueuePhase`, `_validateFighter`)
- Admin functions: clear action verbs (e.g., `setGameEnabled`, `setGauntletSize`)

## Event Naming

- PascalCase with past tense or action (e.g., `PlayerQueued`, `GauntletCompleted`, `GameEnabledUpdated`)

## State Variable Organization

Group state variables with comment headers:

```solidity
// --- Configuration & Roles ---
// --- Dynamic Settings ---
// --- Gauntlet State ---
// --- Queue State ---
// --- Player State ---
```

## Custom Errors

Always prefer custom errors over require strings:

```solidity
error GauntletDoesNotExist();
error PlayerNotInQueue();
error InvalidLoadout();
```

## Error Usage Pattern

```solidity
if (condition) revert ErrorName();
```

## Checks-Effects-Interactions Pattern

```solidity
// Checks
if (!valid) revert InvalidInput();

// Effects
state = newState;

// Interactions
emit EventName();
externalCall();
```

## Event Patterns

- Comprehensive events for all state changes
- Indexed parameters for important identifiers
- Emit events at the end of functions (following checks-effects-interactions)
- Include both old and new values for updates

## Gas Optimization Patterns

- Storage packing in structs (e.g., uint8, uint32 grouped)
- Memory arrays for temporary data
- Batch operations where possible
- Delete mappings when no longer needed
