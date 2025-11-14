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
//                      TROPHY NFT INTERFACE                    //
//==============================================================//
/// @title Trophy NFT Interface for Heavy Helms
/// @notice Interface for monster kill trophy NFTs with dynamic metadata
/// @dev Defines core functionality for trophy NFTs minted on monster kills
interface ITrophyNFT {
    //==============================================================//
    //                          STRUCTS                             //
    //==============================================================//
    /// @notice Trophy metadata for a specific kill
    /// @param monsterId The ID of the killed monster
    /// @param monsterName The resolved name of the killed monster
    /// @param difficulty The difficulty level of the kill (0=Easy, 1=Normal, 2=Hard)
    /// @param killBlock Block number when the monster was killed
    /// @param killerPlayerId The ID of the player who got the kill
    /// @param killerPlayerName The resolved name of the player who got the kill
    struct TrophyMetadata {
        uint32 monsterId;
        string monsterName;
        uint8 difficulty;
        uint256 killBlock;
        uint32 killerPlayerId;
        string killerPlayerName;
    }

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new trophy is minted
    /// @param tokenId The ID of the newly minted trophy
    /// @param recipient Address receiving the trophy
    /// @param monsterId ID of the killed monster
    /// @param monsterName Name of the killed monster
    /// @param difficulty Difficulty of the kill
    /// @param killerPlayerId ID of the player who got the kill
    /// @param killerPlayerName Name of the player who got the kill
    event TrophyMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        uint32 indexed monsterId,
        string monsterName,
        uint8 difficulty,
        uint32 killerPlayerId,
        string killerPlayerName
    );

    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Gets the trophy metadata for a specific token
    /// @param tokenId The token ID to query
    /// @return The TrophyMetadata struct containing kill information
    function getTrophyMetadata(uint256 tokenId) external view returns (TrophyMetadata memory);

    /// @notice Gets the total number of trophies minted
    /// @return The current total supply
    function totalSupply() external view returns (uint256);

    /// @notice Gets the monster type this trophy collection represents
    /// @return The monster type name (e.g., "Goblin", "Undead", "Demon")
    function monsterType() external view returns (string memory);

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Mints a new trophy to the specified address
    /// @param to Address to mint the trophy to
    /// @param monsterId ID of the killed monster
    /// @param monsterName Name of the killed monster
    /// @param difficulty Difficulty of the kill
    /// @param killerPlayerId ID of the player who got the kill
    /// @param killerPlayerName Name of the player who got the kill
    /// @return tokenId The token ID of the newly minted trophy
    function mintTrophy(
        address to,
        uint32 monsterId,
        string calldata monsterName,
        uint8 difficulty,
        uint32 killerPlayerId,
        string calldata killerPlayerName
    ) external returns (uint256 tokenId);
}
