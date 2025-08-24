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

error TokenDoesNotExist();
error InvalidBaseURI();
error MaxSupplyReached();
error InvalidTokenId();
error InvalidMintPrice();
error MintingDisabled();

contract PlayerSkinNFT is IPlayerSkinNFT, ERC721, ConfirmedOwner {
    uint16 private constant _MAX_SUPPLY = 10000;
    uint16 private _currentTokenId = 1;

    bool public mintingEnabled;
    uint256 public mintPrice;

    mapping(uint256 => SkinAttributes) private _skinAttributes;
    string public baseURI;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_, uint256 _mintPrice) ConfirmedOwner(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        mintPrice = _mintPrice;
        mintingEnabled = false; // Start with minting disabled
    }

    /// @notice Returns the token collection name
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the token collection symbol
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function MAX_SUPPLY() external pure override returns (uint16) {
        return _MAX_SUPPLY;
    }

    function CURRENT_TOKEN_ID() external view override returns (uint16) {
        return _currentTokenId;
    }

    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function mintSkin(address to, uint8 weapon, uint8 armor) external payable returns (uint16) {
        // Owner can mint for free, others must pay
        if (msg.sender != owner()) {
            if (!mintingEnabled) revert MintingDisabled();
            if (msg.value != mintPrice) revert InvalidMintPrice();
        }

        if (_currentTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();

        uint16 newTokenId = _currentTokenId++;
        _mint(to, newTokenId);

        _skinAttributes[newTokenId] = SkinAttributes({weapon: weapon, armor: armor});

        emit SkinMinted(newTokenId, weapon, armor);
        return newTokenId;
    }

    function getSkinAttributes(uint256 tokenId) external view override returns (SkinAttributes memory) {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        if (bytes(_baseURI).length == 0) revert InvalidBaseURI();
        baseURI = _baseURI;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (id >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf(id) == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked(baseURI, toString(id), ".json"));
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Helper function to convert uint to string
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // Override ownerOf to match both ERC721 and interface
    function ownerOf(uint256 id) public view virtual override(ERC721, IPlayerSkinNFT) returns (address owner) {
        return super.ownerOf(id);
    }
}
