// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseGame.sol";
import "../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import "../../interfaces/game/engine/IGameEngine.sol";
import "../../interfaces/fighters/IPlayer.sol";
import "../../interfaces/fighters/IDefaultPlayer.sol";
import "../../interfaces/fighters/IMonster.sol";
import "../../fighters/Fighter.sol";

contract PracticeGame is BaseGame {
    IDefaultPlayer public defaultPlayerContract;
    IMonster public monsterContract;

    event DefaultPlayerContractUpdated(address indexed oldContract, address indexed newContract);
    event MonsterContractUpdated(address indexed oldContract, address indexed newContract);

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

    function setDefaultPlayerContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();
        address oldContract = address(defaultPlayerContract);
        defaultPlayerContract = IDefaultPlayer(_newContract);
        emit DefaultPlayerContractUpdated(oldContract, _newContract);
    }

    function setMonsterContract(address _newContract) external onlyOwner {
        if (_newContract == address(0)) revert ZeroAddress();
        address oldContract = address(monsterContract);
        monsterContract = IMonster(_newContract);
        emit MonsterContractUpdated(oldContract, _newContract);
    }

    function _isPlayerIdSupported(uint32 playerId) internal pure override returns (bool) {
        // All fighter types are supported
        return playerId > 0;
    }

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

    function _generatePseudoRandomSeed(uint32 player1Id, uint32 player2Id) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, player1Id, player2Id)));
    }

    function play(Fighter.PlayerLoadout memory player1, Fighter.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        // Get the appropriate Fighter contracts
        Fighter p1Fighter = _getFighterContract(player1.playerId);
        Fighter p2Fighter = _getFighterContract(player2.playerId);

        // Validate Skins for players + Retirement Status for players & monsters
        if (_getFighterType(player1.playerId) == Fighter.FighterType.PLAYER) {
            require(!playerContract.isPlayerRetired(player1.playerId), "Player 1 is retired");
            address owner = IPlayer(playerContract).getPlayerOwner(player1.playerId);
            IPlayer(playerContract).skinRegistry().validateSkinOwnership(player1.skin, owner);
            IPlayer(playerContract).skinRegistry().validateSkinRequirements(
                player1.skin,
                IPlayer(playerContract).getPlayer(player1.playerId).attributes,
                IPlayer(playerContract).equipmentRequirements()
            );
        } else if (_getFighterType(player1.playerId) == Fighter.FighterType.MONSTER) {
            require(!monsterContract.isMonsterRetired(player1.playerId), "Player 1 is retired");
        }

        if (_getFighterType(player2.playerId) == Fighter.FighterType.PLAYER) {
            require(!playerContract.isPlayerRetired(player2.playerId), "Player 2 is retired");
            address owner = IPlayer(playerContract).getPlayerOwner(player2.playerId);
            IPlayer(playerContract).skinRegistry().validateSkinOwnership(player2.skin, owner);
            IPlayer(playerContract).skinRegistry().validateSkinRequirements(
                player2.skin,
                IPlayer(playerContract).getPlayer(player2.playerId).attributes,
                IPlayer(playerContract).equipmentRequirements()
            );
        } else if (_getFighterType(player2.playerId) == Fighter.FighterType.MONSTER) {
            require(!monsterContract.isMonsterRetired(player2.playerId), "Player 2 is retired");
        }

        // Convert loadouts using the appropriate Fighter implementations
        IGameEngine.FighterStats memory p1Combat = p1Fighter.convertToFighterStats(player1);
        IGameEngine.FighterStats memory p2Combat = p2Fighter.convertToFighterStats(player2);

        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(uint32(player1.playerId), uint32(player2.playerId));

        return gameEngine.processGame(p1Combat, p2Combat, pseudoRandomSeed, 0);
    }
}
