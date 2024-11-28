// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/tokens/ERC721.sol";
import "solmate/src/auth/Owned.sol";
import "./interfaces/IPlayerSkinNFT.sol";

contract DefaultPlayerSkinNFT is ERC721, Owned, IPlayerSkinNFT {
    uint16 private constant _MAX_SUPPLY = 1000;
    uint16 private _currentTokenId;

    // Store IPFS CID for each token
    mapping(uint256 => bytes32) private _tokenCIDs;
    mapping(uint256 => SkinAttributes) private _skinAttributes;

    error InvalidCID();
    error InvalidTokenId();
    error MintingDisabled();
    error MaxSupplyReached();

    constructor() ERC721("Shape Duels Characters", "SDC") Owned(msg.sender) {}

    function mintSkin(address to, WeaponType weapon, ArmorType armor, FightingStance stance)
        external
        payable
        override
        onlyOwner
        returns (uint16)
    {
        if (_currentTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();

        uint16 newTokenId = _currentTokenId++;
        _mint(to, newTokenId);

        _skinAttributes[newTokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        emit SkinMinted(to, newTokenId, weapon, armor, stance);
        return newTokenId;
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

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (id >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[id] == address(0)) revert TokenDoesNotExist();

        return string(abi.encodePacked("ipfs://", _bytes32ToHexString(_tokenCIDs[id])));
    }

    // Helper function to set IPFS CID for a token
    function setCID(uint256 tokenId, bytes32 ipfsCID) external onlyOwner {
        if (ipfsCID == bytes32(0)) revert InvalidCID();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        _tokenCIDs[tokenId] = ipfsCID;
    }

    // Helper function to convert bytes32 to hex string
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

    // Add the new event
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
