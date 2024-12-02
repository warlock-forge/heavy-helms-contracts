// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "./IPlayerSkinNFT.sol";
import "../GameStats.sol";
import "../PlayerSkinRegistry.sol";

interface IGameEngine {
    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    function processGame(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 seed,
        IPlayer playerContract,
        GameStats gameStats,
        PlayerSkinRegistry skinRegistry
    ) external view returns (bytes memory);
}
