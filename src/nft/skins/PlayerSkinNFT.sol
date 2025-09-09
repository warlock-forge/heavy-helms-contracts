// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import {ERC721} from "solady/tokens/ERC721.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IPlayerSkinNFT} from "../../interfaces/nft/skins/IPlayerSkinNFT.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when querying a non-existent token
error TokenDoesNotExist();
/// @notice Thrown when an empty base URI is provided
error InvalidBaseURI();
/// @notice Thrown when attempting to mint beyond max supply
error MaxSupplyReached();
/// @notice Thrown when a token ID exceeds uint16 max
error InvalidTokenId();
/// @notice Thrown when incorrect payment amount is sent
error InvalidMintPrice();
/// @notice Thrown when public minting is disabled
error MintingDisabled();

//==============================================================//
//                         HEAVY HELMS                          //
//                       PLAYER SKIN NFT                        //
//==============================================================//
/// @title Player Skin NFT for Heavy Helms
/// @notice Community mintable NFT collection for player skins
/// @dev Extends ERC721 with public minting and owner controls
contract PlayerSkinNFT is IPlayerSkinNFT, ERC721, ConfirmedOwner {
    //==============================================================//
    //                      STATE VARIABLES                         //
    //==============================================================//
    /// @notice Maximum number of tokens that can be minted
    uint16 private constant _MAX_SUPPLY = 10000;
    /// @notice Current token ID counter
    uint16 private _currentTokenId = 1;

    /// @notice Whether public minting is enabled
    bool public mintingEnabled;
    /// @notice Price to mint a new skin
    uint256 public mintPrice;

    /// @notice Maps token IDs to their skin attributes
    mapping(uint256 => SkinAttributes) private _skinAttributes;
    /// @notice Base URI for token metadata
    string public baseURI;

    /// @notice Collection name
    string private _name;
    /// @notice Collection symbol
    string private _symbol;

    //==============================================================//
    //                        CONSTRUCTOR                           //
    //==============================================================//
    /// @notice Initializes the player skin collection
    /// @param name_ The name of the collection
    /// @param symbol_ The symbol of the collection
    /// @param _mintPrice The initial mint price in wei
    constructor(string memory name_, string memory symbol_, uint256 _mintPrice) ConfirmedOwner(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        mintPrice = _mintPrice;
        mintingEnabled = false; // Start with minting disabled
    }

    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    /// @notice Returns the token collection name
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the token collection symbol
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Gets the maximum supply of skins for this collection
    /// @return The maximum number of tokens that can be minted
    function MAX_SUPPLY() external pure override returns (uint16) {
        return _MAX_SUPPLY;
    }

    /// @notice Gets the current token ID counter
    /// @return The current highest token ID minted
    function CURRENT_TOKEN_ID() external view override returns (uint16) {
        return _currentTokenId;
    }

    /// @notice Gets the skin attributes for a specific token
    /// @param tokenId The token ID to query
    /// @return The SkinAttributes struct containing weapon and armor types
    function getSkinAttributes(uint256 tokenId) external view override returns (SkinAttributes memory) {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    /// @notice Returns the metadata URI for a token
    /// @param id The token ID to query
    /// @return The full URI for the token's metadata
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (id >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf(id) == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked(baseURI, toString(id), ".json"));
    }

    /// @notice Gets the owner of a specific token
    /// @param id The token ID to query
    /// @return owner The address that owns the token
    function ownerOf(uint256 id) public view virtual override(ERC721, IPlayerSkinNFT) returns (address owner) {
        return super.ownerOf(id);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Mints a new skin with specified attributes
    /// @param to Address to mint the skin to
    /// @param weapon The weapon type for this skin
    /// @param armor The armor type for this skin
    /// @return newTokenId The token ID of the newly minted skin
    /// @dev Owner can mint for free, others must pay mintPrice
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

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    /// @notice Enables or disables public minting
    /// @param enabled Whether minting should be enabled
    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
    }

    /// @notice Updates the mint price
    /// @param _mintPrice The new price in wei
    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    /// @notice Updates the base URI for metadata
    /// @param _baseURI The new base URI
    function setBaseURI(string memory _baseURI) external onlyOwner {
        if (bytes(_baseURI).length == 0) revert InvalidBaseURI();
        baseURI = _baseURI;
    }

    /// @notice Withdraws accumulated ETH to owner
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Converts a uint256 to its string representation
    /// @param value The number to convert
    /// @return The string representation
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
}
