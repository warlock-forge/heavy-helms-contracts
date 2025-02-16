// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseGame.sol";
import "./interfaces/IPlayerSkinNFT.sol";
import "./interfaces/IDefaultPlayer.sol";
import "./interfaces/IGameEngine.sol";
import "./Fighter.sol";

contract PracticeGame is BaseGame {
    constructor(address _gameEngine, address _playerContract, address _defaultPlayerContract, address _monsterContract)
        BaseGame(_gameEngine, _playerContract, _defaultPlayerContract, _monsterContract)
    {}

    function _generatePseudoRandomSeed(uint32 player1Id, uint32 player2Id) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, player1Id, player2Id)));
    }

    function play(Fighter.PlayerLoadout memory player1, Fighter.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        // Check if either player is retired
        require(!playerContract.isPlayerRetired(player1.playerId), "Player 1 is retired");
        require(!playerContract.isPlayerRetired(player2.playerId), "Player 2 is retired");

        // Get the appropriate Fighter contract for each player
        Fighter p1Fighter = _getFighterContract(player1.playerId);
        Fighter p2Fighter = _getFighterContract(player2.playerId);

        // Convert loadouts using the appropriate Fighter implementations
        IGameEngine.FighterStats memory p1Combat = p1Fighter.convertToFighterStats(player1);
        IGameEngine.FighterStats memory p2Combat = p2Fighter.convertToFighterStats(player2);

        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(uint32(player1.playerId), uint32(player2.playerId));

        return gameEngine.processGame(p1Combat, p2Combat, pseudoRandomSeed, 0);
    }
}
