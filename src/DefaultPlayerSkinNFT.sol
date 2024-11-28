// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayerSkinNFT.sol";
import "./interfaces/IPlayer.sol";
import "./PlayerSkinRegistry.sol";
import "solmate/src/tokens/ERC721.sol";
import "solmate/src/auth/Owned.sol";
import "./interfaces/IDefaultPlayerSkinNFT.sol";

contract DefaultPlayerSkinNFT is ERC721, Owned, IDefaultPlayerSkinNFT {
    uint16 private constant _MAX_SUPPLY = 1000;
    uint16 private _currentTokenId = 1;

    mapping(uint256 => bytes32) private _tokenCIDs;
    mapping(uint256 => SkinAttributes) private _skinAttributes;
    mapping(uint256 => IPlayer.PlayerStats) private _characterStats;

    error InvalidCID();
    error InvalidTokenId();
    error MintingDisabled();
    error MaxSupplyReached();
    error NotPlayerContract();

    constructor() ERC721("Shape Duels Default Player Skins", "SDPS") Owned(msg.sender) {}

    function mintDefaultPlayerSkin(
        WeaponType weapon,
        ArmorType armor,
        FightingStance stance,
        IPlayer.PlayerStats memory stats,
        bytes32 ipfsCID
    ) external override onlyOwner returns (uint16) {
        if (_currentTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();
        if (ipfsCID == bytes32(0)) revert InvalidCID();

        uint16 newTokenId = _currentTokenId++;
        _mint(address(this), newTokenId);

        _skinAttributes[newTokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        _characterStats[newTokenId] = stats;
        _tokenCIDs[newTokenId] = ipfsCID;

        emit DefaultPlayerSkinMinted(newTokenId, stats);
        emit SkinMinted(address(this), newTokenId, weapon, armor, stance);

        // Get Player contract from registry and initialize the default player
        PlayerSkinRegistry registry = PlayerSkinRegistry(payable(owner));
        address playerContractAddress = registry.playerContract();
        IPlayer(playerContractAddress).initializeDefaultPlayer(uint256(newTokenId), stats);

        return newTokenId;
    }

    function getDefaultPlayerStats(uint256 tokenId) external view override returns (IPlayer.PlayerStats memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _characterStats[tokenId];
    }

    function mintSkin(address _to, WeaponType _weapon, ArmorType _armor, FightingStance _stance)
        external
        payable
        override
        returns (uint16)
    {
        revert MintingDisabled();
    }

    function MAX_SUPPLY() external pure override returns (uint16) {
        return _MAX_SUPPLY;
    }

    function CURRENT_TOKEN_ID() external view override returns (uint16) {
        return _currentTokenId;
    }

    function getSkinAttributes(uint256 tokenId) external view override returns (SkinAttributes memory) {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (id >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[id] == address(0)) revert TokenDoesNotExist();

        return string(abi.encodePacked("ipfs://", _bytes32ToHexString(_tokenCIDs[id])));
    }

    function setCID(uint256 tokenId, bytes32 ipfsCID) external onlyOwner {
        if (ipfsCID == bytes32(0)) revert InvalidCID();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        _tokenCIDs[tokenId] = ipfsCID;
    }

    function _bytes32ToHexString(bytes32 data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(64);

        for (uint256 i = 0; i < 32; i++) {
            result[i * 2] = hexChars[uint8(data[i] >> 4)];
            result[i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }

        return string(result);
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    event SkinAttributesUpdated(uint16 indexed tokenId, WeaponType weapon, ArmorType armor, FightingStance stance);

    function updateSkinAttributes(uint256 tokenId, WeaponType weapon, ArmorType armor, FightingStance stance)
        external
        onlyOwner
    {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();

        _skinAttributes[tokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        emit SkinAttributesUpdated(uint16(tokenId), weapon, armor, stance);
    }
}
