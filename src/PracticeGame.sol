// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseGame.sol";
import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";

contract PracticeGame is BaseGame {
    constructor(address _gameEngine, address _playerContract) BaseGame(_gameEngine, _playerContract) {}

    function _generatePseudoRandomSeed(uint256 player1Id, uint256 player2Id) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1), block.prevrandao, block.timestamp, player1Id, player2Id, msg.sender
                )
            )
        );
    }

    function play(IGameEngine.PlayerLoadout memory player1, IGameEngine.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        // Check if either player is retired
        require(!playerContract.isPlayerRetired(player1.playerId), "Player 1 is retired");
        require(!playerContract.isPlayerRetired(player2.playerId), "Player 2 is retired");

        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(player1.playerId, player2.playerId);

        bytes memory results = gameEngine.processGame(player1, player2, pseudoRandomSeed, playerContract);

        return results;
    }
}
