// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/IPlayer.sol";
import "../interfaces/IDefaultPlayer.sol";
import "../interfaces/IMonster.sol";
import "../interfaces/IPlayerSkinNFT.sol";
import "../interfaces/IGameEngine.sol";
import "../interfaces/IPlayerSkinRegistry.sol";

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

    /// @notice Converts a PlayerLoadout to FighterStats using the appropriate contract
    function convertToFighterStats(
        IGameEngine.PlayerLoadout memory playerLoadout,
        IPlayer playerContract,
        IDefaultPlayer defaultPlayerContract,
        IMonster monsterContract,
        IPlayerSkinRegistry skinRegistry
    ) internal view returns (IGameEngine.FighterStats memory) {
        // Get base stats based on player type
        GameHelpers.Attributes memory attributes;
        GameHelpers.PlayerType fighterType = GameHelpers.getPlayerType(playerLoadout.playerId);

        if (fighterType == GameHelpers.PlayerType.DefaultPlayer) {
            IDefaultPlayer.DefaultPlayerStats memory stats =
                defaultPlayerContract.getDefaultPlayer(playerLoadout.playerId);
            attributes = GameHelpers.Attributes({
                strength: stats.strength,
                constitution: stats.constitution,
                size: stats.size,
                agility: stats.agility,
                stamina: stats.stamina,
                luck: stats.luck
            });
        } else if (fighterType == GameHelpers.PlayerType.Monster) {
            IMonster.MonsterStats memory stats = monsterContract.getMonster(playerLoadout.playerId);
            attributes = GameHelpers.Attributes({
                strength: stats.strength,
                constitution: stats.constitution,
                size: stats.size,
                agility: stats.agility,
                stamina: stats.stamina,
                luck: stats.luck
            });
        } else {
            IPlayer.PlayerStats memory stats = playerContract.getPlayer(playerLoadout.playerId);
            attributes = GameHelpers.Attributes({
                strength: stats.strength,
                constitution: stats.constitution,
                size: stats.size,
                agility: stats.agility,
                stamina: stats.stamina,
                luck: stats.luck
            });
        }

        // Get skin attributes
        IPlayerSkinRegistry.SkinInfo memory skinInfo = skinRegistry.getSkin(playerLoadout.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory attrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(playerLoadout.skinTokenId);

        return IGameEngine.FighterStats({
            weapon: attrs.weapon,
            armor: attrs.armor,
            stance: attrs.stance,
            attributes: attributes
        });
    }
}
