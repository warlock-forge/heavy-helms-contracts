// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/auth/Owned.sol";

abstract contract BaseGame is Owned {
    IGameEngine public gameEngine;
    IPlayer public playerContract;

    event GameEngineUpdated(address indexed newEngine);
    event PlayerContractUpdated(address indexed newContract);
    event CombatResult(
        uint32 indexed player1Id, uint32 indexed player2Id, uint32 indexed winningPlayerId, bytes packedResults
    );

    constructor(address _gameEngine, address _playerContract) Owned(msg.sender) {
        gameEngine = IGameEngine(_gameEngine);
        playerContract = IPlayer(_playerContract);
    }

    function setGameEngine(address _newEngine) external onlyOwner {
        gameEngine = IGameEngine(_newEngine);
        emit GameEngineUpdated(_newEngine);
    }

    function setPlayerContract(address _newContract) external onlyOwner {
        playerContract = IPlayer(_newContract);
        emit PlayerContractUpdated(_newContract);
    }
}
