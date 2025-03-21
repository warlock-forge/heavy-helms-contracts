// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../fighters/Fighter.sol";
import "solmate/src/auth/Owned.sol";

error ZeroAddress();

/// @title BaseGame
/// @notice Base contract for game implementations
/// @dev Inherit from this contract to implement specific game types
abstract contract BaseGame is Owned {
    IGameEngine public gameEngine;
    IPlayer public playerContract;

    // Fighter ID ranges - defined here to avoid duplicate code and reduce gas costs
    // These should match the ranges defined in the respective fighter contracts
    uint32 internal constant DEFAULT_PLAYER_END = 2000;
    uint32 internal constant MONSTER_END = 10000;

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

    function _getFighterType(uint32 playerId) internal pure returns (Fighter.FighterType) {
        if (playerId <= DEFAULT_PLAYER_END) {
            return Fighter.FighterType.DEFAULT_PLAYER;
        } else if (playerId <= MONSTER_END) {
            return Fighter.FighterType.MONSTER;
        } else {
            return Fighter.FighterType.PLAYER;
        }
    }

    /// @notice Returns whether a given player ID is supported in this game mode
    /// @param playerId The ID to check
    /// @return True if the player ID is supported, false otherwise
    function _isPlayerIdSupported(uint32 playerId) internal view virtual returns (bool);

    /// @notice Returns the appropriate Fighter contract for a given player ID
    /// @param playerId The ID to check
    /// @return The Fighter contract implementation for this ID
    function _getFighterContract(uint32 playerId) internal view virtual returns (Fighter);
}
