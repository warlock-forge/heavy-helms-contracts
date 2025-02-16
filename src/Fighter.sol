// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayerSkinRegistry.sol";
import "./interfaces/IGameEngine.sol";
import "./interfaces/IPlayerSkinNFT.sol";

abstract contract Fighter {
    struct PlayerLoadout {
        uint32 playerId;
        uint32 skinIndex;
        uint16 skinTokenId;
    }

    struct Attributes {
        uint8 strength;
        uint8 constitution;
        uint8 size;
        uint8 agility;
        uint8 stamina;
        uint8 luck;
    }

    IPlayerSkinRegistry private immutable _skinRegistry;

    function skinRegistry() public view virtual returns (IPlayerSkinRegistry) {
        return _skinRegistry;
    }

    constructor(address skinRegistryAddress) {
        require(skinRegistryAddress != address(0), "Invalid skin registry");
        _skinRegistry = IPlayerSkinRegistry(skinRegistryAddress);
    }

    // Must be implemented by child contracts
    function isValidId(uint32 playerId) public pure virtual returns (bool);

    // Must be implemented by child contracts
    function getFighterAttributes(uint32 playerId) internal view virtual returns (Attributes memory);

    // Get stats with currently equipped skin
    function getFighterStats(uint32 playerId) external view returns (IGameEngine.FighterStats memory) {
        require(isValidId(playerId), "Invalid player ID");

        // Get base attributes
        Attributes memory attributes = getFighterAttributes(playerId);

        // Get current skin info
        (uint32 skinIndex, uint16 skinTokenId) = getCurrentSkin(playerId);

        // Get skin attributes
        IPlayerSkinRegistry skinReg = skinRegistry(); // Get the registry instance first
        IPlayerSkinRegistry.SkinInfo memory skinInfo = skinReg.getSkin(skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(skinTokenId);

        return IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: skinAttrs.stance,
            attributes: attributes
        });
    }

    // Get stats with specific skin loadout
    function convertToFighterStats(PlayerLoadout memory loadout)
        public
        view
        returns (IGameEngine.FighterStats memory)
    {
        require(isValidId(loadout.playerId), "Invalid player ID");

        // Get base attributes
        Attributes memory attributes = getFighterAttributes(loadout.playerId);

        // Get skin data from loadout
        IPlayerSkinRegistry skinReg = skinRegistry();
        IPlayerSkinRegistry.SkinInfo memory skinInfo = skinReg.getSkin(loadout.skinIndex);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs =
            IPlayerSkinNFT(skinInfo.contractAddress).getSkinAttributes(loadout.skinTokenId);

        return IGameEngine.FighterStats({
            weapon: skinAttrs.weapon,
            armor: skinAttrs.armor,
            stance: skinAttrs.stance,
            attributes: attributes
        });
    }

    // Base implementation that forces children to override
    function getCurrentSkin(uint32 playerId) public view virtual returns (uint32 skinIndex, uint16 skinTokenId) {
        revert("Fighter: getCurrentSkin must be implemented");
    }
}
