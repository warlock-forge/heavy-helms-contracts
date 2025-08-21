// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

/// @title IPlayerTickets Interface
/// @notice Interface for PlayerTickets contract used by game modes
interface IPlayerTickets {
    //==============================================================//
    //                      REWARD TYPES                            //
    //==============================================================//

    /// @notice Standardized reward types across all game modes
    /// @dev ATTRIBUTE_SWAP is only used in TournamentGame, not GauntletGame
    enum RewardType {
        NONE,
        ATTRIBUTE_SWAP, // Tournament only - not a ticket
        CREATE_PLAYER_TICKET,
        PLAYER_SLOT_TICKET,
        WEAPON_SPECIALIZATION_TICKET,
        ARMOR_SPECIALIZATION_TICKET,
        DUEL_TICKET,
        NAME_CHANGE_TICKET // Non-fungible NFT

    }

    /// @notice Reward configuration for placement-based distributions
    /// @dev Percentages must sum to 10000 (100.00%)
    struct RewardConfig {
        uint16 nonePercent;
        uint16 attributeSwapPercent; // Set to 0 for game modes without attribute swaps
        uint16 createPlayerPercent;
        uint16 playerSlotPercent;
        uint16 weaponSpecPercent;
        uint16 armorSpecPercent;
        uint16 duelTicketPercent;
        uint16 nameChangePercent;
    }

    //==============================================================//
    //                         FUNCTIONS                            //
    //==============================================================//

    // Token ID constants
    function CREATE_PLAYER_TICKET() external view returns (uint256);
    function PLAYER_SLOT_TICKET() external view returns (uint256);
    function WEAPON_SPECIALIZATION_TICKET() external view returns (uint256);
    function ARMOR_SPECIALIZATION_TICKET() external view returns (uint256);
    function DUEL_TICKET() external view returns (uint256);

    // Minting functions
    function mintFungibleTicket(address to, uint256 ticketType, uint256 amount) external;
    function mintNameChangeNFT(address to, uint256 seed) external returns (uint256 tokenId);
}
