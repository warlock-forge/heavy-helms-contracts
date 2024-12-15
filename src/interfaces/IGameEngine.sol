// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IPlayer.sol";
import "./IPlayerSkinNFT.sol";
import "../PlayerSkinRegistry.sol";

interface IGameEngine {
    /// @notice Returns the current version of the game engine
    function version() external pure returns (uint16);

    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    function processGame(
        PlayerLoadout memory player1,
        PlayerLoadout memory player2,
        uint256 randomSeed,
        IPlayer playerContract
    ) external view returns (bytes memory);
}
