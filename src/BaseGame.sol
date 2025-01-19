// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/auth/Owned.sol";

error ZeroAddress();

/// @title BaseGame
/// @notice Base contract for game implementations
/// @dev Inherit from this contract to implement specific game types
abstract contract BaseGame is Owned {
    IGameEngine public gameEngine;
    IPlayer public playerContract;

    event GameEngineUpdated(address indexed oldEngine, address indexed newEngine);
    event PlayerContractUpdated(address indexed oldContract, address indexed newContract);
    event CombatResult(
        bytes32 indexed player1Data, bytes32 indexed player2Data, uint32 indexed winningPlayerId, bytes packedResults
    );

    constructor(address _gameEngine, address _playerContract) Owned(msg.sender) {
        if (_gameEngine == address(0) || _playerContract == address(0)) revert ZeroAddress();
        gameEngine = IGameEngine(_gameEngine);
        playerContract = IPlayer(_playerContract);
    }

    function setGameEngine(address _newEngine) external onlyOwner {
        if (_newEngine == address(0)) revert ZeroAddress();
        address oldEngine = address(gameEngine);
        gameEngine = IGameEngine(_newEngine);
        emit GameEngineUpdated(oldEngine, _newEngine);
    }

    function setPlayerContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();
        address oldContract = address(playerContract);
        playerContract = IPlayer(_newContract);
        emit PlayerContractUpdated(oldContract, _newContract);
    }
}
