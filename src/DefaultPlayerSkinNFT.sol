// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IPlayerSkinNFT.sol";
import "./PlayerSkinRegistry.sol";
import "solmate/src/tokens/ERC721.sol";
import "solmate/src/auth/Owned.sol";
import "./interfaces/IDefaultPlayerSkinNFT.sol";
import "./interfaces/IDefaultPlayer.sol";

contract DefaultPlayerSkinNFT is ERC721, Owned, IDefaultPlayerSkinNFT {
    uint16 private constant _MAX_SUPPLY = 2000;
    uint16 private _currentTokenId = 1;

    mapping(uint256 => string) private _tokenCIDs;
    mapping(uint256 => SkinAttributes) private _skinAttributes;
    mapping(uint256 => IDefaultPlayer.DefaultPlayerStats) private _characterStats;
    mapping(uint256 => uint256) private _defaultPlayerToToken;

    error InvalidCID();
    error InvalidTokenId();
    error MintingDisabled();
    error MaxSupplyReached();
    error NotPlayerContract();

    event SkinAttributesUpdated(uint16 indexed tokenId, uint8 weapon, uint8 armor, uint8 stance);

    constructor() ERC721("Heavy Helms Default Player Skins", "HHSKIN") Owned(msg.sender) {}

    function mintDefaultPlayerSkin(
        uint8 weapon,
        uint8 armor,
        uint8 stance,
        IDefaultPlayer.DefaultPlayerStats memory stats,
        string memory ipfsCID,
        uint16 desiredTokenId
    ) external override onlyOwner returns (uint16) {
        if (desiredTokenId >= _MAX_SUPPLY) revert MaxSupplyReached();
        if (bytes(ipfsCID).length == 0) revert InvalidCID();
        if (_ownerOf[desiredTokenId] != address(0)) revert("Token ID already exists");

        require(
            bytes(ipfsCID).length > 2 && bytes(ipfsCID)[0] == 0x51 && bytes(ipfsCID)[1] == 0x6D, "Invalid CID format"
        );

        _mint(address(this), desiredTokenId);

        _skinAttributes[desiredTokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});
        _characterStats[desiredTokenId] = stats;
        _tokenCIDs[desiredTokenId] = ipfsCID;
        _defaultPlayerToToken[desiredTokenId] = desiredTokenId;

        if (desiredTokenId >= _currentTokenId) {
            _currentTokenId = desiredTokenId + 1;
        }

        emit DefaultPlayerSkinMinted(desiredTokenId, stats);
        emit SkinMinted(address(this), desiredTokenId, weapon, armor, stance);

        return desiredTokenId;
    }

    function setCID(uint256 tokenId, string calldata ipfsCID) external onlyOwner {
        if (bytes(ipfsCID).length == 0) revert InvalidCID();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        require(
            bytes(ipfsCID).length > 2 && bytes(ipfsCID)[0] == 0x51 && bytes(ipfsCID)[1] == 0x6D, "Invalid CID format"
        );
        _tokenCIDs[tokenId] = ipfsCID;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (id >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[id] == address(0)) revert TokenDoesNotExist();

        return string(abi.encodePacked("ipfs://", _tokenCIDs[id]));
    }

    function getDefaultPlayerStats(uint32 playerId)
        external
        view
        override
        returns (IDefaultPlayer.DefaultPlayerStats memory)
    {
        uint256 tokenId = _defaultPlayerToToken[playerId];
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return _characterStats[tokenId];
    }

    function mintSkin(address, /* _to */ uint8, /* _weapon */ uint8, /* _armor */ uint8 /* _stance */ )
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

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function updateSkinAttributes(uint256 tokenId, uint8 weapon, uint8 armor, uint8 stance) external onlyOwner {
        if (tokenId >= type(uint16).max) revert InvalidTokenId();
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();

        _skinAttributes[tokenId] = SkinAttributes({weapon: weapon, armor: armor, stance: stance});

        emit SkinAttributesUpdated(uint16(tokenId), weapon, armor, stance);
    }

    function ownerOf(uint256 id) public view virtual override(ERC721, IPlayerSkinNFT) returns (address owner) {
        return super.ownerOf(id);
    }
}
