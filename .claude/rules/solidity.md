---
paths: "src/**/*.sol"
---

# Heavy Helms Solidity Rules

## Dependencies

- **Solady** is the primary dependency for gas-optimized contracts. Use Solady's SafeTransferLib, Ownable, etc. If Solady has an implementation, use it instead of writing assembly from scratch.
- **OpenZeppelin** v4.9.6 for ERC standards
- **Chainlink** for VRF 2.5

## Randomness

- **Chainlink VRF 2.5**: Used by Player creation, DuelGame, MonsterBattleGame
- **Blockhash commit-reveal**: Used by GauntletGame and TournamentGame for security and gas efficiency

## Access Control

- Game contracts use a whitelist permission system via `setGameContractPermission`
- Each permission is granular (record, retire, immortal, experience)
- Admin functions are intentional during development — production will use multisig

## Token Handling

- Use Solady's SafeTransferLib for ERC20 interactions
- Player tickets are ERC1155 (fungible IDs 1-99, non-fungible IDs 100+)
- Attribute swap charges are account-bound mappings, NOT NFTs

## Custom Errors

Always prefer custom errors over require strings:
```solidity
if (condition) revert ErrorName();
```

## Checks-Effects-Interactions

Follow strictly for all state-changing functions with external calls.
