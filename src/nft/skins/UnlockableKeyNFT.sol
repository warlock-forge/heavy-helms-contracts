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
import {ERC2981} from "solady/tokens/ERC2981.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when querying a non-existent token
error TokenDoesNotExist();
/// @notice Thrown when an empty base URI is provided
error InvalidBaseURI();
/// @notice Thrown when attempting to mint beyond max supply
error MaxSupplyReached();
/// @notice Thrown when public mint supply is exhausted
error PublicMintExhausted();
/// @notice Thrown when incorrect payment amount is sent
error InvalidMintPrice();
/// @notice Thrown when public minting is disabled
error MintingDisabled();
/// @notice Thrown when mint amount is zero or exceeds limit
error InvalidMintAmount();

//==============================================================//
//                         HEAVY HELMS                          //
//                      UNLOCKABLE KEY NFT                      //
//==============================================================//
/// @title Unlockable Key NFT for Heavy Helms
/// @notice ERC721 token that unlocks access to skin collections
/// @dev Extends ERC721 with ERC2981 royalties, public minting, and owner reserves
contract UnlockableKeyNFT is ERC721, ERC2981, ConfirmedOwner {
    //==============================================================//
    //                      STATE VARIABLES                         //
    //==============================================================//
    /// @notice Maximum number of tokens that can be minted
    uint16 public immutable MAX_SUPPLY;
    /// @notice Maximum number of tokens available for public mint
    uint16 public immutable PUBLIC_SUPPLY;

    /// @notice Current token ID counter (starts at 1)
    uint16 private _currentTokenId;
    /// @notice Number of tokens minted via public mint
    uint16 public publicMinted;

    /// @notice Whether public minting is enabled
    bool public mintingEnabled;
    /// @notice Price to mint a new token
    uint256 public mintPrice;

    /// @notice Base URI for token metadata
    string public baseURI;
    /// @notice Collection name
    string private _name;
    /// @notice Collection symbol
    string private _symbol;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a token is minted
    event KeyMinted(address indexed to, uint16 indexed tokenId);
    /// @notice Emitted when minting is enabled/disabled
    event MintingEnabledUpdated(bool enabled);
    /// @notice Emitted when mint price is updated
    event MintPriceUpdated(uint256 newPrice);
    /// @notice Emitted when base URI is updated
    event BaseURIUpdated(string newBaseURI);

    //==============================================================//
    //                        CONSTRUCTOR                           //
    //==============================================================//
    /// @notice Initializes the unlockable key collection
    /// @param name_ The name of the collection
    /// @param symbol_ The symbol of the collection
    /// @param maxSupply_ Maximum total supply
    /// @param publicSupply_ Maximum public mint supply
    /// @param mintPrice_ The initial mint price in wei
    /// @param royaltyReceiver Address to receive royalties
    /// @param royaltyBps Royalty percentage in basis points (e.g., 500 = 5%)
    constructor(
        string memory name_,
        string memory symbol_,
        uint16 maxSupply_,
        uint16 publicSupply_,
        uint256 mintPrice_,
        address royaltyReceiver,
        uint96 royaltyBps
    ) ConfirmedOwner(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        MAX_SUPPLY = maxSupply_;
        PUBLIC_SUPPLY = publicSupply_;
        mintPrice = mintPrice_;
        mintingEnabled = false;
        _currentTokenId = 1;

        // Set default royalty
        _setDefaultRoyalty(royaltyReceiver, royaltyBps);
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

    /// @notice Gets the current token ID counter
    /// @return The next token ID to be minted
    function currentTokenId() external view returns (uint16) {
        return _currentTokenId;
    }

    /// @notice Gets the number of tokens remaining for public mint
    /// @return The number of tokens still available for public minting
    function publicMintRemaining() external view returns (uint16) {
        return PUBLIC_SUPPLY > publicMinted ? PUBLIC_SUPPLY - publicMinted : 0;
    }

    /// @notice Returns the metadata URI for a token
    /// @dev All tokens share the same metadata/image
    /// @param id The token ID to query
    /// @return The full URI for the token's metadata
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (!_exists(id)) revert TokenDoesNotExist();
        return baseURI;
    }

    /// @notice Check if contract supports an interface
    /// @param interfaceId The interface identifier
    /// @return True if the interface is supported
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Public mint function
    /// @return tokenId The token ID of the newly minted token
    function mint() external payable returns (uint16 tokenId) {
        if (!mintingEnabled) revert MintingDisabled();
        if (msg.value != mintPrice) revert InvalidMintPrice();
        if (publicMinted >= PUBLIC_SUPPLY) revert PublicMintExhausted();
        if (_currentTokenId > MAX_SUPPLY) revert MaxSupplyReached();

        tokenId = _currentTokenId++;
        publicMinted++;

        _mint(msg.sender, tokenId);
        emit KeyMinted(msg.sender, tokenId);
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    /// @notice Owner mint function for reserves
    /// @param to Address to mint tokens to
    /// @param amount Number of tokens to mint
    function ownerMint(address to, uint16 amount) external onlyOwner {
        if (amount == 0) revert InvalidMintAmount();
        if (_currentTokenId + amount - 1 > MAX_SUPPLY) revert MaxSupplyReached();

        for (uint16 i = 0; i < amount; i++) {
            uint16 tokenId = _currentTokenId++;
            _mint(to, tokenId);
            emit KeyMinted(to, tokenId);
        }
    }

    /// @notice Enables or disables public minting
    /// @param enabled Whether minting should be enabled
    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
        emit MintingEnabledUpdated(enabled);
    }

    /// @notice Updates the mint price
    /// @param newPrice The new price in wei
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    /// @notice Updates the base URI for metadata
    /// @param newBaseURI The new base URI
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        if (bytes(newBaseURI).length == 0) revert InvalidBaseURI();
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /// @notice Updates the default royalty configuration
    /// @param receiver Address to receive royalties
    /// @param bps Royalty percentage in basis points
    function setDefaultRoyalty(address receiver, uint96 bps) external onlyOwner {
        _setDefaultRoyalty(receiver, bps);
    }

    /// @notice Withdraws accumulated ETH to owner
    function withdraw() external onlyOwner {
        SafeTransferLib.safeTransferETH(owner(), address(this).balance);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Converts a uint256 to its string representation
    /// @param value The number to convert
    /// @return The string representation
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

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
