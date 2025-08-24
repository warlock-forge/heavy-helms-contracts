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
import "../interfaces/fighters/IMonster.sol";
import "../interfaces/fighters/registries/names/IMonsterNameRegistry.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "./Fighter.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when attempting to use an invalid monster ID outside the monster range
error InvalidMonsterRange();
/// @notice Thrown when attempting to access a monster that doesn't exist
error MonsterDoesNotExist();
/// @notice Thrown when a caller doesn't have the required permission
error UnauthorizedCaller();
/// @notice Thrown when a required address argument is the zero address
error BadZeroAddress();

//==============================================================//
//                         HEAVY HELMS                          //
//                           MONSTER                            //
//==============================================================//
/// @title Monster Contract for Heavy Helms
/// @notice Manages monster characters for the game
/// @dev Monsters are system-controlled characters (IDs 2001-10000)
contract Monster is IMonster, ConfirmedOwner, Fighter {
    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the name registry contract for monster names
    IMonsterNameRegistry private immutable _nameRegistry;

    /// @notice ID range constants for monsters
    /// @dev Monsters occupy IDs 2001-10000
    uint32 private constant MONSTER_ID_START = 2001;
    uint32 private constant MONSTER_ID_END = 10000;

    /// @notice Next available monster ID
    uint32 private _nextMonsterId = MONSTER_ID_START;

    /// @notice Maps monster ID to their stats progression across all levels
    /// @dev Each monster has complete stats for levels 1-10
    mapping(uint32 => MonsterStats[10]) private _monsterProgressions;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a monster's win/loss record is updated
    /// @param monsterId The ID of the monster
    /// @param wins Current number of wins
    /// @param losses Current number of losses
    event MonsterWinLossUpdated(uint32 indexed monsterId, uint16 wins, uint16 losses);

    /// @notice Emitted when a monster's kill count is updated
    /// @param monsterId The ID of the monster
    /// @param kills Current number of kills
    event MonsterKillsUpdated(uint32 indexed monsterId, uint16 kills);

    /// @notice Emitted when a monster's immortality status is changed
    /// @param monsterId The ID of the monster
    /// @param immortal New immortality status
    event MonsterImmortalStatusUpdated(uint32 indexed monsterId, bool immortal);

    /// @notice Emitted when a monster's retirement status is changed
    /// @param monsterId The ID of the monster
    /// @param retired New retirement status
    event MonsterRetired(uint32 indexed monsterId, bool retired);

    /// @notice Emitted when a new monster is created
    /// @param monsterId The ID of the newly created monster
    /// @param stats The stats for the new monster
    event MonsterCreated(uint32 indexed monsterId, MonsterStats stats);

    /// @notice Emitted when a monster's stats are updated
    /// @param monsterId The ID of the monster
    /// @param stats The new stats for the monster
    event MonsterStatsUpdated(uint32 indexed monsterId, MonsterStats stats);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Ensures the monster ID is within valid range and exists
    /// @param monsterId The ID of the monster to check
    /// @dev Reverts with InvalidMonsterRange or MonsterDoesNotExist if validation fails
    modifier monsterExists(uint32 monsterId) {
        if (!isValidId(monsterId)) {
            revert InvalidMonsterRange();
        }
        if (_monsterProgressions[monsterId][0].attributes.strength == 0) {
            revert MonsterDoesNotExist();
        }
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    /// @notice Initializes the Monster contract
    /// @param skinRegistryAddress Address of the skin registry contract
    /// @param nameRegistryAddress Address of the name registry contract
    /// @dev Reverts with BadZeroAddress if name registry address is zero
    constructor(address skinRegistryAddress, address nameRegistryAddress)
        ConfirmedOwner(msg.sender)
        Fighter(skinRegistryAddress)
    {
        if (nameRegistryAddress == address(0)) {
            revert BadZeroAddress();
        }
        _nameRegistry = IMonsterNameRegistry(nameRegistryAddress);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    // View Functions
    /// @notice Gets the name registry contract reference
    /// @return The MonsterNameRegistry contract instance
    function nameRegistry() public view returns (IMonsterNameRegistry) {
        return _nameRegistry;
    }

    /// @notice Check if a monster ID is valid
    /// @param monsterId The ID to check
    /// @return bool True if the ID is within valid monster range
    function isValidId(uint32 monsterId) public pure override(Fighter, IMonster) returns (bool) {
        return monsterId >= MONSTER_ID_START && monsterId <= MONSTER_ID_END;
    }

    /// @notice Gets the complete stats for a monster at a specific level
    /// @param monsterId The ID of the monster to query
    /// @param level The level to get stats for (1-10)
    /// @return The monster's complete stats and attributes at the specified level
    function getMonster(uint32 monsterId, uint8 level)
        external
        view
        monsterExists(monsterId)
        returns (MonsterStats memory)
    {
        require(level >= 1 && level <= 10, "Invalid level");
        return _monsterProgressions[monsterId][level - 1];
    }

    /// @notice Gets the skin registry contract reference
    /// @return The PlayerSkinRegistry contract instance
    function skinRegistry() public view override(Fighter, IMonster) returns (IPlayerSkinRegistry) {
        return super.skinRegistry();
    }

    // State-Changing Functions
    /// @notice Creates a new monster with specified stats for all levels
    /// @param allLevelStats Array of stats for levels 1-10
    /// @return The ID of the created monster
    /// @dev Only callable by the contract owner
    function createMonster(MonsterStats[10] memory allLevelStats) external onlyOwner returns (uint32) {
        if (_nextMonsterId > MONSTER_ID_END) revert InvalidMonsterRange();

        uint32 monsterId = _nextMonsterId++;
        _monsterProgressions[monsterId] = allLevelStats;

        emit MonsterCreated(monsterId, allLevelStats[0]); // Emit level 1 stats for backwards compatibility
        return monsterId;
    }

    /// @notice Updates the stats of an existing monster for all levels
    /// @param monsterId The ID of the monster to update
    /// @param newAllLevelStats The new stats to assign to the monster for all levels 1-10
    /// @dev Only callable by the contract owner, requires monster to exist
    function updateMonsterStats(uint32 monsterId, MonsterStats[10] memory newAllLevelStats)
        external
        onlyOwner
        monsterExists(monsterId)
    {
        _monsterProgressions[monsterId] = newAllLevelStats;

        emit MonsterStatsUpdated(monsterId, newAllLevelStats[0]); // Emit level 1 stats for backwards compatibility
    }
}
