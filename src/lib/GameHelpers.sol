// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library GameHelpers {
    enum PlayerType {
        DefaultPlayer,
        Monster,
        PlayerCharacter
    }

    struct Attributes {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
    }

    /// @notice Helper to identify player type from ID
    /// @param id The player ID to check
    /// @return PlayerType indicating if it's a default player, monster, or player character
    function getPlayerType(uint32 id) internal pure returns (PlayerType) {
        if (id <= 2000) return PlayerType.DefaultPlayer;
        if (id <= 10000) return PlayerType.Monster;
        return PlayerType.PlayerCharacter;
    }
}
