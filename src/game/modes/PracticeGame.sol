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
import "./BaseGame.sol";
import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IDefaultPlayer.sol";
import "../../interfaces/fighters/IMonster.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                        PRACTICE GAME                         //
//==============================================================//
/// @title Practice Game Mode for Heavy Helms
/// @notice Allows players to practice fighting against any fighter type without consequences
/// @dev Supports players, default players, and monsters in a non-competitive environment
contract PracticeGame is BaseGame {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the default player contract
    IDefaultPlayer public defaultPlayerContract;

    /// @notice Reference to the monster contract
    IMonster public monsterContract;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when the default player contract is updated
    /// @param oldContract Address of the previous contract
    /// @param newContract Address of the new contract
    event DefaultPlayerContractUpdated(address indexed oldContract, address indexed newContract);

    /// @notice Emitted when the monster contract is updated
    /// @param oldContract Address of the previous contract
    /// @param newContract Address of the new contract
    event MonsterContractUpdated(address indexed oldContract, address indexed newContract);

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the PracticeGame contract
    /// @param _gameEngine Address of the game engine contract
    /// @param _playerContract Address of the player contract
    /// @param _defaultPlayerContract Address of the default player contract
    /// @param _monsterContract Address of the monster contract
    /// @dev Validates that ID ranges match between contracts and base game constants
    constructor(address _gameEngine, address _playerContract, address _defaultPlayerContract, address _monsterContract)
        BaseGame(_gameEngine, _playerContract)
    {
        if (_defaultPlayerContract == address(0) || _monsterContract == address(0)) revert ZeroAddress();

        defaultPlayerContract = IDefaultPlayer(_defaultPlayerContract);
        monsterContract = IMonster(_monsterContract);

        // Validate that our constants match the actual Fighter implementations
        require(
            defaultPlayerContract.isValidId(DEFAULT_PLAYER_END)
                && !defaultPlayerContract.isValidId(DEFAULT_PLAYER_END + 1),
            "DEFAULT_PLAYER_END constant mismatch"
        );
        require(
            monsterContract.isValidId(MONSTER_END) && !monsterContract.isValidId(MONSTER_END + 1),
            "MONSTER_END constant mismatch"
        );
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Sets a new default player contract
    /// @param _newContract Address of the new contract
    /// @dev Only callable by the contract owner
    function setDefaultPlayerContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();
        address oldContract = address(defaultPlayerContract);
        defaultPlayerContract = IDefaultPlayer(_newContract);
        emit DefaultPlayerContractUpdated(oldContract, _newContract);
    }

    /// @notice Sets a new monster contract
    /// @param _newContract Address of the new contract
    /// @dev Only callable by the contract owner
    function setMonsterContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();
        address oldContract = address(monsterContract);
        monsterContract = IMonster(_newContract);
        emit MonsterContractUpdated(oldContract, _newContract);
    }

    /// @notice Simulates a combat between two fighters
    /// @param player1 Loadout for the first fighter
    /// @param player2 Loadout for the second fighter
    /// @return bytes Encoded combat results
    /// @dev Validates fighter eligibility and generates a pseudo-random seed for combat
    function play(Fighter.PlayerLoadout memory player1, Fighter.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        // Fights with same playerId cause inconsistent results
        require(player1.playerId != player2.playerId, "Cannot fight yourself");
        // Get the appropriate Fighter contracts
        Fighter p1Fighter = _getFighterContract(player1.playerId);
        Fighter p2Fighter = _getFighterContract(player2.playerId);

        // Validate fighters
        _validateFighter(player1, 1);
        _validateFighter(player2, 2);

        // Convert loadouts using the appropriate Fighter implementations
        IGameEngine.FighterStats memory p1Combat = p1Fighter.convertToFighterStats(player1);
        IGameEngine.FighterStats memory p2Combat = p2Fighter.convertToFighterStats(player2);

        // Generate a pseudo-random seed and process the game
        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(player1.playerId, player2.playerId);
        return gameEngine.processGame(p1Combat, p2Combat, pseudoRandomSeed, 0);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Checks if a player ID is supported in practice mode
    /// @param playerId The ID to check
    /// @return Always returns true as all IDs > 0 are supported
    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        // All fighter types are supported
        return playerId > 0;
    }

    /// @notice Returns the appropriate Fighter contract for a given player ID
    /// @param playerId The ID to check
    /// @return The Fighter contract implementation for this ID
    function _getFighterContract(uint32 playerId) internal view override returns (Fighter) {
        Fighter.FighterType fighterType = _getFighterType(playerId);

        if (fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            return Fighter(address(defaultPlayerContract));
        } else if (fighterType == Fighter.FighterType.MONSTER) {
            return Fighter(address(monsterContract));
        } else {
            return Fighter(address(playerContract));
        }
    }

    /// @notice Validates a fighter's eligibility for combat
    /// @param fighter The fighter loadout to validate
    /// @param playerNumber Used for error messages (1 or 2)
    /// @dev Checks retirement status and skin validation for applicable fighter types
    function _validateFighter(Fighter.PlayerLoadout memory fighter, uint8 playerNumber) internal view {
        Fighter.FighterType fighterType = _getFighterType(fighter.playerId);

        if (fighterType == Fighter.FighterType.PLAYER) {
            require(
                !playerContract.isPlayerRetired(fighter.playerId),
                string(abi.encodePacked("Player ", bytes1(playerNumber + 48), " is retired"))
            );

            address owner = IPlayer(playerContract).getPlayerOwner(fighter.playerId);
            IPlayer(playerContract).skinRegistry().validateSkinOwnership(fighter.skin, owner);
            IPlayer(playerContract).skinRegistry().validateSkinRequirements(
                fighter.skin,
                IPlayer(playerContract).getPlayer(fighter.playerId).attributes,
                IPlayer(playerContract).equipmentRequirements()
            );
        } else if (fighterType == Fighter.FighterType.MONSTER) {
            require(
                !monsterContract.isMonsterRetired(fighter.playerId),
                string(abi.encodePacked("Player ", bytes1(playerNumber + 48), " is retired"))
            );
        }
    }

    //==============================================================//
    //                    PRIVATE FUNCTIONS                         //
    //==============================================================//
    /// @notice Generates a pseudo-random seed for combat
    /// @param player1Id ID of the first fighter
    /// @param player2Id ID of the second fighter
    /// @return A pseudo-random number derived from block data and fighter IDs
    function _generatePseudoRandomSeed(uint32 player1Id, uint32 player2Id) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, player1Id, player2Id)));
    }
}
