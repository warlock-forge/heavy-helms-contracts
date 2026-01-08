---
paths: src/**/*.sol
---

# Player Progression & Ticket System

## DO NOT CONFUSE: Four Types of Tickets/Charges

**IMPORTANT**: Every ticket/charge is BURNED ON USE (either actual NFT burn or mapping counter decrement)

## Type 1: ETH OR Ticket (Dual Option)

- **Examples**: Player Creation (CREATE_PLAYER_TICKET), Player Slots (PLAYER_SLOT_TICKET)
- **Implementation**: Users can EITHER burn the NFT ticket OR pay ETH
- **Methods**: Can be same method with conditional logic OR separate methods (e.g., `purchasePlayerSlotsWithETH` + `purchasePlayerSlotsWithTickets`)

## Type 2: Ticket Only (Fungible NFT)

- **Examples**: Weapon Specialization (WEAPON_SPECIALIZATION_TICKET), Armor Specialization (ARMOR_SPECIALIZATION_TICKET)
- **Implementation**: MUST burn the fungible NFT ticket - NO ETH option
- **Storage**: ERC1155 fungible tokens (IDs 1-99)

## Type 3: Ticket Only (Non-Fungible NFT)

- **Examples**: Name Changes (name NFTs with embedded name indices)
- **Implementation**: MUST burn the specific NFT - NO ETH option
- **Storage**: ERC1155 non-fungible tokens (IDs 100+)
- **Special**: NFT contains metadata (e.g., specific name indices)

## Type 4: Bind-on-Account Charges (NOT NFTs)

- **Examples**: Attribute Swaps (via `_attributeSwapCharges` mapping)
- **Implementation**: Uses internal contract mappings, NOT PlayerTickets NFTs
- **Storage**: `mapping(address => uint256)` in Player contract
- **Purpose**: Account-bound to prevent pay-to-win mechanics
- **Award**: Via `awardAttributeSwap()` by authorized game contracts
- **Use**: Decrements mapping counter when used

## Current Implementation Status

- Type 1 (ETH or Ticket): Player slots AND player creation work correctly with both options
- Type 2 (Fungible Ticket): Weapon/armor specialization work correctly
- Type 3 (Non-Fungible): Name changes work correctly
- Type 4 (Account Charges): Attribute swaps work correctly

## Key Implementation Details

- **Slot Cost**: Fixed cost system - `slotBatchCost` constant, no scaling
- **Reentrancy**: No guards needed - no actual reentrancy risks identified
- **DRY Principle**: Shared `_addPlayerSlots` internal function for both ETH and ticket purchases
