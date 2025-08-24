// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {ERC721} from "solady/tokens/ERC721.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "../../interfaces/nft/skins/IPlayerSkinNFT.sol";

error InvalidCID();
error InvalidTokenId();
error MaxSupplyReached();
error TokenDoesNotExist();
error TokenIdAlreadyExists(uint16 tokenId);

abstract contract GameOwnedNFT is ERC721, ConfirmedOwner, IPlayerSkinNFT {
    uint16 internal immutable _MAX_SUPPLY;
    uint16 internal _currentTokenId = 1;

    string private _name;
    string private _symbol;

    mapping(uint256 => string) internal _tokenCIDs;
    mapping(uint256 => SkinAttributes) internal _skinAttributes;

    // Common events
    event SkinAttributesUpdated(uint16 indexed tokenId, uint8 weapon, uint8 armor);
    event CIDUpdated(uint16 indexed tokenId, string newCID);

    constructor(string memory name_, string memory symbol_, uint16 maxSupply) ConfirmedOwner(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        _MAX_SUPPLY = maxSupply;
    }

    /// @notice Returns the token collection name
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the token collection symbol
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function _mintGameSkin(uint8 weapon, uint8 armor, string memory ipfsCid, uint16 desiredTokenId)
        internal
        returns (uint16)
    {
        if (desiredTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();
        if (bytes(ipfsCid).length == 0) revert InvalidCID();
        if (_ownerOf(desiredTokenId) != address(0)) revert TokenIdAlreadyExists(desiredTokenId);

        _mint(address(this), desiredTokenId);

        _skinAttributes[desiredTokenId] = SkinAttributes({weapon: weapon, armor: armor});
        _tokenCIDs[desiredTokenId] = ipfsCid;

        if (desiredTokenId >= _currentTokenId) {
            _currentTokenId = desiredTokenId + 1;
        }

        return desiredTokenId;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (_ownerOf(id) == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked("ipfs://", _tokenCIDs[id]));
    }

    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    function MAX_SUPPLY() external view returns (uint16) {
        return _MAX_SUPPLY;
    }

    function CURRENT_TOKEN_ID() external view returns (uint16) {
        return _currentTokenId;
    }

    function setCID(uint256 tokenId, string calldata ipfsCid) external onlyOwner {
        if (bytes(ipfsCid).length == 0) revert InvalidCID();
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        _tokenCIDs[tokenId] = ipfsCid;
        emit CIDUpdated(uint16(tokenId), ipfsCid);
    }

    function updateSkinAttributes(uint256 tokenId, uint8 weapon, uint8 armor) external onlyOwner {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _skinAttributes[tokenId] = SkinAttributes({weapon: weapon, armor: armor});

        emit SkinAttributesUpdated(uint16(tokenId), weapon, armor);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function ownerOf(uint256 id) public view virtual override(ERC721, IPlayerSkinNFT) returns (address owner) {
        return super.ownerOf(id);
    }
}
