// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/auth/Owned.sol";

error ZeroAddress();
error InvalidGameEngine();
error InvalidPlayerContract();

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

        // Validate game engine interface
        try IGameEngine(_gameEngine).version() returns (uint32) {}
        catch {
            revert InvalidGameEngine();
        }

        // Validate player contract interface
        try IPlayer(_playerContract).maxPlayersPerAddress() returns (uint256) {}
        catch {
            revert InvalidPlayerContract();
        }

        gameEngine = IGameEngine(_gameEngine);
        playerContract = IPlayer(_playerContract);
    }

    function setGameEngine(address _newEngine) external onlyOwner {
        if (_newEngine == address(0)) revert ZeroAddress();

        // Validate interface implementation
        try IGameEngine(_newEngine).version() returns (uint32) {}
        catch {
            revert InvalidGameEngine();
        }

        address oldEngine = address(gameEngine);
        gameEngine = IGameEngine(_newEngine);
        emit GameEngineUpdated(oldEngine, _newEngine);
    }

    function setPlayerContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();

        // Validate interface implementation
        try IPlayer(_newContract).maxPlayersPerAddress() returns (uint256) {}
        catch {
            revert InvalidPlayerContract();
        }

        address oldContract = address(playerContract);
        playerContract = IPlayer(_newContract);
        emit PlayerContractUpdated(oldContract, _newContract);
    }
}
