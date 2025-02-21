// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/tokens/ERC721.sol";
import "solmate/src/auth/Owned.sol";
import "./interfaces/IPlayerSkinNFT.sol";

error InvalidCID();
error InvalidTokenId();
error MaxSupplyReached();
error TokenDoesNotExist();

abstract contract GameOwnedNFT is ERC721, Owned, IPlayerSkinNFT {
    uint16 internal immutable _MAX_SUPPLY;
    uint16 internal _currentTokenId = 1;

    mapping(uint256 => string) internal _tokenCIDs;
    mapping(uint256 => SkinAttributes) internal _skinAttributes;

    // Common events
    event SkinAttributesUpdated(uint16 indexed tokenId, uint8 weapon, uint8 armor, uint8 stance);

    constructor(string memory name, string memory symbol, uint16 maxSupply) ERC721(name, symbol) Owned(msg.sender) {
        _MAX_SUPPLY = maxSupply;
    }

    function _mintGameSkin(uint8 weapon, uint8 armor, uint8 stance, string memory ipfsCID, uint16 desiredTokenId)
        internal
        returns (uint16)
    {
        if (desiredTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();
        if (bytes(ipfsCID).length == 0) revert InvalidCID();
        if (_ownerOf[desiredTokenId] != address(0)) revert("Token ID already exists");

        _mint(address(this), desiredTokenId);

        _skinAttributes[desiredTokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});
        _tokenCIDs[desiredTokenId] = ipfsCID;

        if (desiredTokenId >= _currentTokenId) {
            _currentTokenId = desiredTokenId + 1;
        }

        emit SkinMinted(address(this), desiredTokenId, weapon, armor, stance);

        return desiredTokenId;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (_ownerOf[id] == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked("ipfs://", _tokenCIDs[id]));
    }

    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    function MAX_SUPPLY() external view returns (uint16) {
        return _MAX_SUPPLY;
    }

    function CURRENT_TOKEN_ID() external view returns (uint16) {
        return _currentTokenId;
    }

    function setCID(uint256 tokenId, string calldata ipfsCID) external onlyOwner {
        if (bytes(ipfsCID).length == 0) revert InvalidCID();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        _tokenCIDs[tokenId] = ipfsCID;
    }

    function updateSkinAttributes(uint256 tokenId, uint8 weapon, uint8 armor, uint8 stance) external onlyOwner {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();

        _skinAttributes[tokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        emit SkinAttributesUpdated(uint16(tokenId), weapon, armor, stance);
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function ownerOf(uint256 id) public view virtual override(ERC721, IPlayerSkinNFT) returns (address owner) {
        return super.ownerOf(id);
    }
}
