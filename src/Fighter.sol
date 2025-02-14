// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayerSkinRegistry.sol";
import "./lib/GameHelpers.sol";

abstract contract Fighter {
    IPlayerSkinRegistry public immutable skinRegistry;

    constructor(address _skinRegistry) {
        require(_skinRegistry != address(0), "Invalid skin registry");
        skinRegistry = IPlayerSkinRegistry(_skinRegistry);
    }

    // Must be implemented by child contracts
    function isValidId(uint32 playerId) public pure virtual returns (bool);

    // Shared implementation
    function getSkinData(uint32 playerId) public view virtual returns (uint32 skinIndex, uint16 skinTokenId) {
        require(isValidId(playerId), "Invalid player ID");
        // Common skin data retrieval logic
    }

    // Must be implemented by child contracts
    function getFighterStats(uint32 playerId) external view virtual returns (GameHelpers.Attributes memory);
}
