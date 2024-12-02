// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayer.sol";
import "solmate/src/auth/Owned.sol";

contract Game is Owned {
    IGameEngine public gameEngine;
    IPlayer public playerContract;
    uint256 public entryFee;

    event GameEngineUpdated(address indexed newEngine);
    event ContractUpdated(string indexed contractName, address indexed newContract);
    event CombatResult(
        uint32 indexed player1Id,
        uint32 indexed player2Id,
        uint256 randomSeed,
        bytes packedResults,
        uint32 winningPlayerId
    );

    constructor(address _gameEngine, address _playerContract) Owned(msg.sender) {
        gameEngine = IGameEngine(_gameEngine);
        playerContract = IPlayer(_playerContract);
        entryFee = 0.001 ether;
    }

    function setGameEngine(address _newEngine) external onlyOwner {
        gameEngine = IGameEngine(_newEngine);
        emit GameEngineUpdated(_newEngine);
    }

    function setPlayerContract(address _newContract) external onlyOwner {
        playerContract = IPlayer(_newContract);
        emit ContractUpdated("Player", _newContract);
    }

    function setEntryFee(uint256 _entryFee) external onlyOwner {
        entryFee = _entryFee;
    }

    function _generatePseudoRandomSeed(uint256 player1Id, uint256 player2Id) private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1), block.prevrandao, block.timestamp, player1Id, player2Id, msg.sender
                )
            )
        );
    }

    function practiceGame(IGameEngine.PlayerLoadout memory player1, IGameEngine.PlayerLoadout memory player2)
        public
        view
        returns (bytes memory)
    {
        uint256 pseudoRandomSeed = _generatePseudoRandomSeed(player1.playerId, player2.playerId);
        return gameEngine.processGame(player1, player2, pseudoRandomSeed, playerContract);
    }

    function requestRandomSeedFromVRF() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp)));
    }

    function officialGame(IGameEngine.PlayerLoadout memory player1, IGameEngine.PlayerLoadout memory player2)
        public
        payable
        returns (bytes memory)
    {
        require(msg.value >= entryFee, "Insufficient entry fee");
        uint256 vrfSeed = requestRandomSeedFromVRF();
        bytes memory results = gameEngine.processGame(player1, player2, vrfSeed, playerContract);

        // Map winner (1 or 2) to actual player ID
        uint32 winningPlayerId = uint8(results[0]) == 1 ? player1.playerId : player2.playerId;

        emit CombatResult(player1.playerId, player2.playerId, vrfSeed, results, winningPlayerId);
        return results;
    }

    // Add this function for testing
    function debugGame(IGameEngine.PlayerLoadout memory player1, IGameEngine.PlayerLoadout memory player2, uint256 seed)
        public
        view
        returns (bytes memory)
    {
        return gameEngine.processGame(player1, player2, seed, playerContract);
    }
}
