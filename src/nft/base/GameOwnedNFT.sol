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
/// @notice Thrown when an empty CID is provided
error InvalidCID();
/// @notice Thrown when a token ID exceeds uint16 max
error InvalidTokenId();
/// @notice Thrown when attempting to mint beyond max supply
error MaxSupplyReached();
/// @notice Thrown when querying a non-existent token
error TokenDoesNotExist();
/// @notice Thrown when attempting to mint an already existing token ID
error TokenIdAlreadyExists(uint16 tokenId);

//==============================================================//
//                         HEAVY HELMS                          //
//                       GAME OWNED NFT                         //
//==============================================================//
/// @title Game Owned NFT Base Contract for Heavy Helms
/// @notice Abstract base contract for game-controlled NFT collections
/// @dev Extends ERC721 with skin attributes and IPFS metadata storage
abstract contract GameOwnedNFT is ERC721, ConfirmedOwner, IPlayerSkinNFT {
    //==============================================================//
    //                      STATE VARIABLES                         //
    //==============================================================//
    /// @notice Maximum number of tokens that can be minted
    uint16 internal immutable _MAX_SUPPLY;
    /// @notice Current token ID counter
    uint16 internal _currentTokenId = 1;

    /// @notice Collection name
    string private _name;
    /// @notice Collection symbol
    string private _symbol;

    /// @notice Maps token IDs to their IPFS CIDs
    mapping(uint256 => string) internal _tokenCIDs;
    /// @notice Maps token IDs to their skin attributes
    mapping(uint256 => SkinAttributes) internal _skinAttributes;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when skin attributes are updated
    /// @param tokenId The updated token's ID
    /// @param weapon The new weapon type
    /// @param armor The new armor type
    event SkinAttributesUpdated(uint16 indexed tokenId, uint8 weapon, uint8 armor);

    /// @notice Emitted when a token's CID is updated
    /// @param tokenId The updated token's ID
    /// @param newCID The new IPFS CID
    event CIDUpdated(uint16 indexed tokenId, string newCID);

    //==============================================================//
    //                        CONSTRUCTOR                           //
    //==============================================================//
    /// @notice Initializes the NFT collection
    /// @param name_ The name of the collection
    /// @param symbol_ The symbol of the collection
    /// @param maxSupply The maximum supply for this collection
    constructor(string memory name_, string memory symbol_, uint16 maxSupply) ConfirmedOwner(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        _MAX_SUPPLY = maxSupply;
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

    /// @notice Returns the metadata URI for a token
    /// @param id The token ID to query
    /// @return The IPFS URI for the token's metadata
    function tokenURI(uint256 id) public view override returns (string memory) {
        if (_ownerOf(id) == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked("ipfs://", _tokenCIDs[id]));
    }

    /// @notice Gets the skin attributes for a specific token
    /// @param tokenId The token ID to query
    /// @return The SkinAttributes struct containing weapon and armor types
    function getSkinAttributes(uint256 tokenId) external view returns (SkinAttributes memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _skinAttributes[tokenId];
    }

    /// @notice Gets the maximum supply of skins for this collection
    /// @return The maximum number of tokens that can be minted
    function MAX_SUPPLY() external view returns (uint16) {
        return _MAX_SUPPLY;
    }

    /// @notice Gets the current token ID counter
    /// @return The current highest token ID minted
    function CURRENT_TOKEN_ID() external view returns (uint16) {
        return _currentTokenId;
    }

    /// @notice Gets the owner of a specific token
    /// @param id The token ID to query
    /// @return owner The address that owns the token
    function ownerOf(uint256 id) public view virtual override(ERC721, IPlayerSkinNFT) returns (address owner) {
        return super.ownerOf(id);
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Mints a new game skin with specific attributes
    /// @param weapon The weapon type for this skin
    /// @param armor The armor type for this skin
    /// @param ipfsCid The IPFS content identifier for the skin's metadata
    /// @param desiredTokenId The desired token ID to mint
    /// @return The token ID of the newly minted skin
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

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    /// @notice Updates the CID for an existing token
    /// @param tokenId The token ID to update
    /// @param ipfsCid The new IPFS CID
    function setCID(uint256 tokenId, string calldata ipfsCid) external onlyOwner {
        if (bytes(ipfsCid).length == 0) revert InvalidCID();
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        _tokenCIDs[tokenId] = ipfsCid;
        emit CIDUpdated(uint16(tokenId), ipfsCid);
    }

    /// @notice Updates the skin attributes for an existing token
    /// @param tokenId The token ID to update
    /// @param weapon The new weapon type
    /// @param armor The new armor type
    function updateSkinAttributes(uint256 tokenId, uint8 weapon, uint8 armor) external onlyOwner {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _skinAttributes[tokenId] = SkinAttributes({weapon: weapon, armor: armor});

        emit SkinAttributesUpdated(uint16(tokenId), weapon, armor);
    }

    /// @notice Withdraws accumulated ETH to owner
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
