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
import {BaseGame, ZeroAddress} from "./BaseGame.sol";
import {IGameEngine} from "../../interfaces/game/engine/IGameEngine.sol";
import {IDefaultPlayer} from "../../interfaces/fighters/IDefaultPlayer.sol";
import {IMonster} from "../../interfaces/fighters/IMonster.sol";
import {IPlayer} from "../../interfaces/fighters/IPlayer.sol";
import {IPlayerSkinNFT} from "../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import {Fighter} from "../../fighters/Fighter.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

//==============================================================//
//                         HEAVY HELMS                          //
//                        PRACTICE GAME                         //
//==============================================================//
/// @title Practice Game Mode for Heavy Helms
/// @notice Allows players to practice fighting against any fighter type without consequences
/// @dev Supports players, default players, and monsters in a non-competitive environment
contract PracticeGame is BaseGame, ConfirmedOwner {
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
    constructor(
        address _gameEngine,
        address payable _playerContract,
        address _defaultPlayerContract,
        address _monsterContract
    ) BaseGame(_gameEngine, _playerContract) ConfirmedOwner(msg.sender) {
        if (_defaultPlayerContract == address(0) || _monsterContract == address(0)) {
            revert ZeroAddress();
        }

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

    /// @notice Sets a new game engine address
    /// @param _newEngine Address of the new game engine
    /// @dev Only callable by the contract owner
    function setGameEngine(address _newEngine) public override(BaseGame) onlyOwner {
        super.setGameEngine(_newEngine);
    }

    /// @notice Simulates a combat between two fighters (Player2 mirrors Player1's level)
    /// @param player1 Loadout for the first fighter (must be a Player)
    /// @param player2 Loadout for the second fighter
    /// @return bytes Encoded combat results
    function play(Fighter.PlayerLoadout memory player1, Fighter.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        // Enforce that Player1 is a Player
        require(_getFighterType(player1.playerId) == Fighter.FighterType.PLAYER, "Player1 must be a Player");

        // Get Player1's level to mirror for Player2
        uint8 player1Level = IPlayer(playerContract).getPlayer(player1.playerId).level;

        // Call level-aware version with Player1's level for Player2
        return play(player1, player2, player1Level);
    }

    /// @notice Simulates a combat between two fighters with level control for Player2
    /// @param player1 Loadout for the first fighter (must be a Player)
    /// @param player2 Loadout for the second fighter
    /// @param player2Level Level to use for Player2 (ignored if Player2 is a Player)
    /// @return bytes Encoded combat results
    /// @dev Validates fighter eligibility and generates a pseudo-random seed for combat
    function play(Fighter.PlayerLoadout memory player1, Fighter.PlayerLoadout memory player2, uint8 player2Level)
        public
        view
        returns (bytes memory)
    {
        // Enforce that Player1 is a Player
        require(_getFighterType(player1.playerId) == Fighter.FighterType.PLAYER, "Player1 must be a Player");

        // Fights with same playerId cause inconsistent results
        require(player1.playerId != player2.playerId, "Cannot fight yourself");

        // Get the appropriate Fighter contracts
        Fighter p1Fighter = _getFighterContract(player1.playerId);
        Fighter p2Fighter = _getFighterContract(player2.playerId);

        // Validate fighters
        _validateFighter(player1, 1);
        _validateFighter(player2, 2);

        // Get player stats and convert to FighterStats
        IGameEngine.FighterStats memory p1Combat = _createFighterStats(p1Fighter, player1, 0); // Player1 uses intrinsic level
        IGameEngine.FighterStats memory p2Combat = _createFighterStats(p2Fighter, player2, player2Level);

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
            IPlayer(playerContract).skinRegistry()
                .validateSkinRequirements(
                    fighter.skin,
                    IPlayer(playerContract).getPlayer(fighter.playerId).attributes,
                    IPlayer(playerContract).equipmentRequirements()
                );
        }
    }

    /// @notice Creates FighterStats from a PlayerLoadout
    /// @param fighter The Fighter contract instance
    /// @param loadout The player loadout
    /// @param levelOverride Level to use for DefaultPlayer/Monster (0 = use intrinsic for Players)
    /// @return FighterStats struct ready for the game engine
    function _createFighterStats(Fighter fighter, Fighter.PlayerLoadout memory loadout, uint8 levelOverride)
        internal
        view
        returns (IGameEngine.FighterStats memory)
    {
        Fighter.FighterType fighterType = _getFighterType(loadout.playerId);

        // Handle each fighter type separately since they return different struct types
        if (fighterType == Fighter.FighterType.PLAYER) {
            // Players always use their intrinsic level (ignore levelOverride)
            IPlayer.PlayerStats memory playerStats = IPlayer(address(fighter)).getPlayer(loadout.playerId);
            // Apply loadout overrides for configurable battle choices
            playerStats.skin = loadout.skin;
            playerStats.stance = loadout.stance;

            // Get skin attributes and construct FighterStats
            IPlayerSkinNFT.SkinAttributes memory skinAttrs = fighter.getSkinAttributes(playerStats.skin);
            return IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: playerStats.stance,
                attributes: playerStats.attributes,
                level: playerStats.level,
                weaponSpecialization: playerStats.weaponSpecialization,
                armorSpecialization: playerStats.armorSpecialization
            });
        } else if (fighterType == Fighter.FighterType.DEFAULT_PLAYER) {
            // Validate level range, fallback to reasonable default
            uint8 level = (levelOverride >= 1 && levelOverride <= 10) ? levelOverride : 5;
            IPlayer.PlayerStats memory defaultStats =
                IDefaultPlayer(address(fighter)).getDefaultPlayer(loadout.playerId, level);
            // Apply loadout overrides for configurable battle choices
            defaultStats.skin = loadout.skin;
            defaultStats.stance = loadout.stance;

            // Get skin attributes and construct FighterStats
            IPlayerSkinNFT.SkinAttributes memory skinAttrs = fighter.getSkinAttributes(defaultStats.skin);
            return IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: defaultStats.stance,
                attributes: defaultStats.attributes,
                level: defaultStats.level,
                weaponSpecialization: defaultStats.weaponSpecialization,
                armorSpecialization: defaultStats.armorSpecialization
            });
        } else {
            // Fighter.FighterType.MONSTER - validate level range
            uint8 level = (levelOverride >= 1 && levelOverride <= 10) ? levelOverride : 5;
            IMonster.MonsterStats memory monsterStats = IMonster(address(fighter)).getMonster(loadout.playerId, level);
            // Apply loadout overrides for configurable battle choices
            monsterStats.skin = loadout.skin;
            monsterStats.stance = loadout.stance;

            // Get skin attributes and construct FighterStats
            IPlayerSkinNFT.SkinAttributes memory skinAttrs = fighter.getSkinAttributes(monsterStats.skin);
            return IGameEngine.FighterStats({
                weapon: skinAttrs.weapon,
                armor: skinAttrs.armor,
                stance: monsterStats.stance,
                attributes: monsterStats.attributes,
                level: monsterStats.level,
                weaponSpecialization: monsterStats.weaponSpecialization,
                armorSpecialization: monsterStats.armorSpecialization
            });
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
