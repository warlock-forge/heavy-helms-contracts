// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseGame.sol";
import "./interfaces/IPlayerSkinNFT.sol";

contract PracticeGame is BaseGame {
    constructor(address _gameEngine, address _playerContract) BaseGame(_gameEngine, _playerContract) {}

    function _generatePseudoRandomSeed(uint32 player1Id, uint32 player2Id) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, player1Id, player2Id)));
    }

    function play(IGameEngine.PlayerLoadout memory player1, IGameEngine.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        // Check if either player is retired
        require(!playerContract.isPlayerRetired(player1.playerId), "Player 1 is retired");
        require(!playerContract.isPlayerRetired(player2.playerId), "Player 2 is retired");

        // Get player stats
        IPlayer.PlayerStats memory p1Stats = playerContract.getPlayer(player1.playerId);
        p1Stats.skinIndex = player1.skinIndex;
        p1Stats.skinTokenId = player1.skinTokenId;

        IPlayer.PlayerStats memory p2Stats = playerContract.getPlayer(player2.playerId);
        p2Stats.skinIndex = player2.skinIndex;
        p2Stats.skinTokenId = player2.skinTokenId;

        // Get skin attributes for both players
        IPlayerSkinRegistry.SkinInfo memory p1SkinInfo = playerContract.skinRegistry().getSkin(player1.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory p1Attrs =
            IPlayerSkinNFT(p1SkinInfo.contractAddress).getSkinAttributes(player1.skinTokenId);

        IPlayerSkinRegistry.SkinInfo memory p2SkinInfo = playerContract.skinRegistry().getSkin(player2.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory p2Attrs =
            IPlayerSkinNFT(p2SkinInfo.contractAddress).getSkinAttributes(player2.skinTokenId);

        // Create combat loadouts
        IGameEngine.CombatLoadout memory p1Combat = IGameEngine.CombatLoadout({
            playerId: player1.playerId,
            weapon: p1Attrs.weapon,
            armor: p1Attrs.armor,
            stance: p1Attrs.stance,
            stats: p1Stats
        });

        IGameEngine.CombatLoadout memory p2Combat = IGameEngine.CombatLoadout({
            playerId: player2.playerId,
            weapon: p2Attrs.weapon,
            armor: p2Attrs.armor,
            stance: p2Attrs.stance,
            stats: p2Stats
        });

        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(uint32(player1.playerId), uint32(player2.playerId));

        return gameEngine.processGame(p1Combat, p2Combat, pseudoRandomSeed, 0);
    }
}
