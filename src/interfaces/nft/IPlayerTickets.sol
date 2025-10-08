// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                         HEAVY HELMS                          //
//                   PLAYER TICKETS INTERFACE                   //
//==============================================================//
/// @title Player Tickets Interface for Heavy Helms
/// @notice Defines functionality for game reward tickets and NFTs
/// @dev Used by game contracts to mint rewards for players
interface IPlayerTickets {
    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Standardized reward types across all game modes
    enum RewardType {
        NONE, // No reward
        ATTRIBUTE_SWAP, // Soulbound NFT ticket
        CREATE_PLAYER_TICKET, // Fungible ticket for player creation
        PLAYER_SLOT_TICKET, // Fungible ticket for additional slots
        WEAPON_SPECIALIZATION_TICKET, // Fungible ticket for weapon mastery
        ARMOR_SPECIALIZATION_TICKET, // Fungible ticket for armor mastery
        DUEL_TICKET, // Fungible ticket for duel games
        DAILY_RESET_TICKET, // Fungible ticket for gauntlet resets
        NAME_CHANGE_TICKET // Non-fungible NFT with name data
    }

    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Reward configuration for placement-based distributions
    /// @param nonePercent Chance of no reward (basis points)
    /// @param attributeSwapPercent Chance of attribute swap ticket
    /// @param createPlayerPercent Chance of player creation ticket
    /// @param playerSlotPercent Chance of player slot ticket
    /// @param weaponSpecPercent Chance of weapon specialization ticket
    /// @param armorSpecPercent Chance of armor specialization ticket
    /// @param duelTicketPercent Chance of duel ticket
    /// @param dailyResetPercent Chance of daily reset ticket
    /// @param nameChangePercent Chance of name change NFT
    /// @dev Percentages must sum to 10000 (100.00%)
    struct RewardConfig {
        uint16 nonePercent;
        uint16 attributeSwapPercent;
        uint16 createPlayerPercent;
        uint16 playerSlotPercent;
        uint16 weaponSpecPercent;
        uint16 armorSpecPercent;
        uint16 duelTicketPercent;
        uint16 dailyResetPercent;
        uint16 nameChangePercent;
    }

    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Gets the token ID for player creation tickets
    /// @return The constant token ID for CREATE_PLAYER_TICKET
    function CREATE_PLAYER_TICKET() external view returns (uint256);

    /// @notice Gets the token ID for player slot tickets
    /// @return The constant token ID for PLAYER_SLOT_TICKET
    function PLAYER_SLOT_TICKET() external view returns (uint256);

    /// @notice Gets the token ID for weapon specialization tickets
    /// @return The constant token ID for WEAPON_SPECIALIZATION_TICKET
    function WEAPON_SPECIALIZATION_TICKET() external view returns (uint256);

    /// @notice Gets the token ID for armor specialization tickets
    /// @return The constant token ID for ARMOR_SPECIALIZATION_TICKET
    function ARMOR_SPECIALIZATION_TICKET() external view returns (uint256);

    /// @notice Gets the token ID for duel tickets
    /// @return The constant token ID for DUEL_TICKET
    function DUEL_TICKET() external view returns (uint256);

    /// @notice Gets the token ID for daily reset tickets
    /// @return The constant token ID for DAILY_RESET_TICKET
    function DAILY_RESET_TICKET() external view returns (uint256);

    /// @notice Gets the token ID for attribute swap tickets
    /// @return The constant token ID for ATTRIBUTE_SWAP_TICKET
    function ATTRIBUTE_SWAP_TICKET() external view returns (uint256);

    //==============================================================//
    //                  STATE-CHANGING FUNCTIONS                    //
    //==============================================================//
    /// @notice Mints fungible tickets to a recipient
    /// @param to Address to mint tickets to
    /// @param ticketType Token ID of the ticket type to mint
    /// @param amount Number of tickets to mint
    function mintFungibleTicket(address to, uint256 ticketType, uint256 amount) external;

    /// @notice Mints a unique name change NFT with embedded name data
    /// @param to Address to mint the NFT to
    /// @param seed Random seed for name generation
    /// @return tokenId The ID of the newly minted NFT
    function mintNameChangeNFT(address to, uint256 seed) external returns (uint256 tokenId);

    /// @notice Gas-limited minting for fungible tickets (DoS protection)
    /// @param to Address to mint tickets to
    /// @param ticketType Token ID of the ticket type to mint
    /// @param amount Number of tickets to mint
    /// @dev Implements gas limits to prevent DoS attacks during batch minting
    function mintFungibleTicketSafe(address to, uint256 ticketType, uint256 amount) external;

    /// @notice Gas-limited minting for name change NFTs (DoS protection)
    /// @param to Address to mint the NFT to
    /// @param seed Random seed for name generation
    /// @return tokenId The ID of the newly minted NFT
    /// @dev Implements gas limits to prevent DoS attacks during batch minting
    function mintNameChangeNFTSafe(address to, uint256 seed) external returns (uint256 tokenId);

    /// @notice Burns tickets from a specified address
    /// @param from Address to burn tickets from
    /// @param id Token ID to burn
    /// @param amount Number of tokens to burn
    function burnFrom(address from, uint256 id, uint256 amount) external;
}
