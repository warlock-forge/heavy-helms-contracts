// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../fighters/Fighter.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when a zero address is provided where not allowed
error ZeroAddress();

//==============================================================//
//                         HEAVY HELMS                          //
//                          BASE GAME                           //
//==============================================================//
/// @title BaseGame
/// @notice Base contract for game implementations
/// @dev Inherit from this contract to implement specific game types
abstract contract BaseGame is ConfirmedOwner {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Interface to the game engine contract
    IGameEngine public gameEngine;

    /// @notice Interface to the player contract
    IPlayer public playerContract;

    // Fighter ID ranges - defined here to avoid duplicate code and reduce gas costs
    // These should match the ranges defined in the respective fighter contracts
    /// @notice End of the default player ID range
    uint32 internal constant DEFAULT_PLAYER_END = 2000;
    /// @notice End of the monster ID range
    uint32 internal constant MONSTER_END = 10000;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when the game engine address is updated
    event GameEngineUpdated(address indexed oldEngine, address indexed newEngine);

    /// @notice Emitted when the player contract address is updated
    event PlayerContractUpdated(address indexed oldContract, address indexed newContract);

    /// @notice Emitted when a combat is completed with results
    event CombatResult(
        bytes32 indexed player1Data, bytes32 indexed player2Data, uint32 indexed winningPlayerId, bytes packedResults
    );

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the BaseGame contract
    /// @param _gameEngine Address of the game engine contract
    /// @param _playerContract Address of the player contract
    /// @dev Reverts if either address is zero
    constructor(address _gameEngine, address payable _playerContract) ConfirmedOwner(msg.sender) {
        if (_gameEngine == address(0) || _playerContract == address(0)) revert ZeroAddress();
        gameEngine = IGameEngine(_gameEngine);
        playerContract = IPlayer(_playerContract);
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    /// @notice Sets a new game engine address
    /// @param _newEngine Address of the new game engine
    /// @dev Only callable by the contract owner
    function setGameEngine(address _newEngine) external onlyOwner {
        if (_newEngine == address(0)) revert ZeroAddress();
        address oldEngine = address(gameEngine);
        gameEngine = IGameEngine(_newEngine);
        emit GameEngineUpdated(oldEngine, _newEngine);
    }

    /// @notice Sets a new player contract address
    /// @param _newContract Address of the new player contract
    /// @dev Only callable by the contract owner
    function setPlayerContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();
        address oldContract = address(playerContract);
        playerContract = IPlayer(_newContract);
        emit PlayerContractUpdated(oldContract, _newContract);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Determines the fighter type based on ID range
    /// @param playerId The ID to check
    /// @return The fighter type (DEFAULT_PLAYER, MONSTER, or PLAYER)
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
