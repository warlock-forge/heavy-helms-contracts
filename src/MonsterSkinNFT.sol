// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IGameDefinitions.sol";
import "./PlayerSkinRegistry.sol";
import "solmate/src/tokens/ERC721.sol";
import "solmate/src/auth/Owned.sol";

contract MonsterSkinNFT is ERC721, Owned {
    // Add the struct definition from IPlayerSkinNFT
    struct SkinAttributes {
        IGameDefinitions.WeaponType weapon;
        IGameDefinitions.ArmorType armor;
        IGameDefinitions.FightingStance stance;
    }

    uint16 private constant _MAX_SUPPLY = 8000;
    uint16 private _currentTokenId = 1;

    // Core mappings from DefaultPlayerSkinNFT
    mapping(uint256 => string) private _tokenCIDs;
    mapping(uint256 => SkinAttributes) private _skinAttributes;

    // Monster-specific mappings
    mapping(uint256 => uint8) private _monsterTiers;

    // Events
    event MonsterSkinMinted(uint16 indexed tokenId, uint8 tier);
    event SkinMinted(
        address indexed owner,
        uint16 indexed tokenId,
        IGameDefinitions.WeaponType weapon,
        IGameDefinitions.ArmorType armor,
        IGameDefinitions.FightingStance stance
    );
    event MonsterTierUpdated(uint16 indexed tokenId, uint8 newTier);

    // Errors
    error InvalidCID();
    error InvalidTokenId();
    error MaxSupplyReached();
    error TokenDoesNotExist();

    constructor() ERC721("Heavy Helms Monster Skins", "HHMON") Owned(msg.sender) {}

    function mintMonsterSkin(
        IGameDefinitions.WeaponType weapon,
        IGameDefinitions.ArmorType armor,
        IGameDefinitions.FightingStance stance,
        uint8 tier,
        string memory ipfsCID,
        uint16 desiredTokenId
    ) external onlyOwner returns (uint16) {
        if (desiredTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();
        if (bytes(ipfsCID).length == 0) revert InvalidCID();
        if (_ownerOf[desiredTokenId] != address(0)) revert("Token ID already exists");

        require(
            bytes(ipfsCID).length > 2 && bytes(ipfsCID)[0] == 0x51 && bytes(ipfsCID)[1] == 0x6D, "Invalid CID format"
        );

        _mint(address(this), desiredTokenId);

        _skinAttributes[desiredTokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        _monsterTiers[desiredTokenId] = tier;
        _tokenCIDs[desiredTokenId] = ipfsCID;

        if (desiredTokenId >= _currentTokenId) {
            _currentTokenId = desiredTokenId + 1;
        }

        emit MonsterSkinMinted(desiredTokenId, tier);
        emit SkinMinted(address(this), desiredTokenId, weapon, armor, stance);

        return desiredTokenId;
    }

    // Getters
    function getMonsterTier(uint256 tokenId) external view returns (uint8) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _monsterTiers[tokenId];
    }

    function updateMonsterTier(uint256 tokenId, uint8 newTier) external onlyOwner {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        _monsterTiers[tokenId] = newTier;
        emit MonsterTierUpdated(uint16(tokenId), newTier);
    }

    // Standard overrides
    function tokenURI(uint256 id) public view override returns (string memory) {
        if (_ownerOf[id] == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked("ipfs://", _tokenCIDs[id]));
    }

    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }
}
