// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "solmate/src/tokens/ERC1155.sol";
import "solmate/src/auth/Owned.sol";
import "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when caller doesn't have required permission
error NotAuthorizedToMint();
/// @notice Thrown when attempting to set zero address
error ZeroAddress();
/// @notice Thrown when token ID doesn't exist
error TokenDoesNotExist();

//==============================================================//
//                      PLAYER TICKETS                          //
//==============================================================//
/// @title PlayerTickets - Game utility tokens for Heavy Helms
/// @notice Manages both fungible utility tickets and non-fungible name change NFTs
/// @dev All tickets are tradeable on OpenSea
contract PlayerTickets is ERC1155, Owned {
    //==============================================================//
    //                     TOKEN ID CONSTANTS                       //
    //==============================================================//
    // Fungible ticket IDs (1-99)
    uint256 public constant CREATE_PLAYER_TICKET = 1;
    uint256 public constant PLAYER_SLOT_TICKET = 2;
    uint256 public constant WEAPON_SPECIALIZATION_TICKET = 3;
    uint256 public constant ARMOR_SPECIALIZATION_TICKET = 4;
    uint256 public constant DUEL_TICKET = 5;
    // Reserved for future fungible tickets: 6-99

    // Non-fungible name change NFTs start at 100
    uint256 public nextNameChangeTokenId = 100;

    //==============================================================//
    //                        STRUCTS                               //
    //==============================================================//
    /// @notice Data stored for each name change NFT
    struct NameData {
        uint16 firstNameIndex;
        uint16 surnameIndex;
    }

    /// @notice Permissions for game contracts to mint different ticket types
    struct GamePermissions {
        bool playerCreation;
        bool playerSlots;
        bool nameChanges;
        bool weaponSpecialization;
        bool armorSpecialization;
        bool duels;
    }

    //==============================================================//
    //                          ENUMS                               //
    //==============================================================//
    /// @notice Types of permissions that can be granted to game contracts
    enum TicketPermission {
        PLAYER_CREATION,
        PLAYER_SLOTS,
        NAME_CHANGES,
        WEAPON_SPECIALIZATION,
        ARMOR_SPECIALIZATION,
        DUELS
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Reference to the player name registry for resolving names
    IPlayerNameRegistry private immutable _nameRegistry;

    /// @notice Maps name change NFT token IDs to their name data
    mapping(uint256 => NameData) public nameChangeData;

    /// @notice Maps game contract addresses to their granted permissions
    mapping(address => GamePermissions) private _gameContractPermissions;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when game contract permissions are updated
    event GameContractPermissionsUpdated(address indexed gameContract, GamePermissions permissions);

    /// @notice Emitted when a name change NFT is minted
    event NameChangeNFTMinted(uint256 indexed tokenId, address indexed to, uint16 firstNameIndex, uint16 surnameIndex);

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    /// @notice Modifier to check if the calling contract has a specific permission
    /// @param permission The permission type to check
    modifier hasPermission(TicketPermission permission) {
        if (msg.sender != owner) {
            GamePermissions memory permissions = _gameContractPermissions[msg.sender];
            bool hasRequiredPermission;

            if (permission == TicketPermission.PLAYER_CREATION) {
                hasRequiredPermission = permissions.playerCreation;
            } else if (permission == TicketPermission.PLAYER_SLOTS) {
                hasRequiredPermission = permissions.playerSlots;
            } else if (permission == TicketPermission.NAME_CHANGES) {
                hasRequiredPermission = permissions.nameChanges;
            } else if (permission == TicketPermission.WEAPON_SPECIALIZATION) {
                hasRequiredPermission = permissions.weaponSpecialization;
            } else if (permission == TicketPermission.ARMOR_SPECIALIZATION) {
                hasRequiredPermission = permissions.armorSpecialization;
            } else if (permission == TicketPermission.DUELS) {
                hasRequiredPermission = permissions.duels;
            }

            if (!hasRequiredPermission) revert NotAuthorizedToMint();
        }
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor(address nameRegistryAddress) Owned(msg.sender) {
        if (nameRegistryAddress == address(0)) revert ZeroAddress();
        _nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Returns the URI for a given token ID
    /// @param id The token ID to get URI for
    /// @return The URI string
    function uri(uint256 id) public view override returns (string memory) {
        if (id == CREATE_PLAYER_TICKET) return "ipfs://create-player-ticket";
        if (id == PLAYER_SLOT_TICKET) return "ipfs://player-slot-ticket";
        if (id == WEAPON_SPECIALIZATION_TICKET) return "ipfs://weapon-specialization-ticket";
        if (id == ARMOR_SPECIALIZATION_TICKET) return "ipfs://armor-specialization-ticket";
        if (id == DUEL_TICKET) return "ipfs://duel-ticket";
        if (id >= 100) return _generateNameChangeURI(id);
        return "";
    }

    /// @notice Generates dynamic SVG-based URI for name change NFTs
    /// @param tokenId The token ID to generate URI for
    /// @return The complete data URI with embedded SVG and metadata
    function _generateNameChangeURI(uint256 tokenId) internal view returns (string memory) {
        // Check if token exists by checking if it's been minted
        if (tokenId < 100 || tokenId >= nextNameChangeTokenId) revert TokenDoesNotExist();

        NameData memory data = nameChangeData[tokenId];

        // Get the actual names from the registry
        (string memory firstName, string memory surname) =
            _nameRegistry.getFullName(data.firstNameIndex, data.surnameIndex);

        // Generate SVG image
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                "<defs>",
                '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
                '<stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />',
                '<stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />',
                "</linearGradient>",
                '<filter id="glow">',
                '<feGaussianBlur stdDeviation="3" result="coloredBlur"/>',
                '<feMerge><feMergeNode in="coloredBlur"/><feMergeNode in="SourceGraphic"/></feMerge>',
                "</filter>",
                "</defs>",
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Name Change Certificate</text>',
                '<text x="200" y="200" text-anchor="middle" fill="white" font-size="28" font-family="serif" font-weight="bold" filter="url(#glow)">',
                firstName,
                "</text>",
                '<text x="200" y="240" text-anchor="middle" fill="white" font-size="28" font-family="serif" font-weight="bold" filter="url(#glow)">',
                surname,
                "</text>",
                '<circle cx="100" cy="320" r="3" fill="gold" opacity="0.7"/>',
                '<circle cx="300" cy="320" r="3" fill="gold" opacity="0.7"/>',
                '<text x="200" y="340" text-anchor="middle" fill="gold" font-size="12" font-family="serif">',
                unicode"⚔️ CERTIFIED WARRIOR ⚔️",
                "</text>",
                "</svg>"
            )
        );

        // Generate JSON metadata
        string memory json = string(
            abi.encodePacked(
                "{",
                '"name":"Name Change: ',
                firstName,
                " ",
                surname,
                '",',
                '"description":"Changes player name to ',
                firstName,
                " ",
                surname,
                '. Burn this NFT to apply the name change.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"First Name","value":"',
                firstName,
                '"},',
                '{"trait_type":"Surname","value":"',
                surname,
                '"},',
                '{"trait_type":"Token ID","value":"',
                LibString.toString(tokenId),
                '"},',
                '{"trait_type":"Type","value":"Name Change Certificate"}',
                "]",
                "}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Mints fungible tickets to a recipient
    /// @param to Address to mint tickets to
    /// @param ticketType The type of ticket to mint
    /// @param amount Number of tickets to mint
    function mintFungibleTicket(address to, uint256 ticketType, uint256 amount)
        external
        hasPermission(_getRequiredPermission(ticketType))
    {
        _mint(to, ticketType, amount, "");
    }

    /// @notice Mints a name change NFT with randomized name selection
    /// @param to Address to mint the NFT to
    /// @param seed External seed to ensure admin cannot cherry-pick names
    /// @return tokenId The ID of the newly minted NFT
    function mintNameChangeNFT(address to, uint256 seed)
        external
        hasPermission(TicketPermission.NAME_CHANGES)
        returns (uint256 tokenId)
    {
        // Combine external seed with blockchain data to prevent manipulation
        uint256 entropy = uint256(
            keccak256(
                abi.encode(seed, block.timestamp, block.prevrandao, to, nextNameChangeTokenId, address(this).balance)
            )
        );

        // Get current name counts from registry
        uint16 setBLength = _nameRegistry.getNameSetBLength();
        uint16 setALength = _nameRegistry.getNameSetALength();
        uint16 surnameLength = _nameRegistry.getSurnamesLength();

        // Calculate total first names available
        uint256 totalFirstNames = uint256(setALength) + uint256(setBLength);

        // Pick a random first name with proportional probability
        uint256 firstNameRandom = entropy % totalFirstNames;
        uint16 firstNameIndex;

        if (firstNameRandom < setBLength) {
            // Selected from Set B (indices 0 to setBLength-1)
            firstNameIndex = uint16(firstNameRandom);
        } else {
            // Selected from Set A (indices 1000+)
            firstNameIndex = _nameRegistry.getSetAStart() + uint16(firstNameRandom - setBLength);
        }

        // Pick a random surname using different part of entropy
        uint16 surnameIndex = uint16((entropy >> 128) % surnameLength);

        // Create the NFT with the randomized indices
        tokenId = nextNameChangeTokenId++;
        nameChangeData[tokenId] = NameData({firstNameIndex: firstNameIndex, surnameIndex: surnameIndex});
        _mint(to, tokenId, 1, "");

        emit NameChangeNFTMinted(tokenId, to, firstNameIndex, surnameIndex);
    }

    /// @notice Gets the name data for a name change NFT
    /// @param tokenId The token ID to get name data for
    /// @return firstNameIndex The first name index
    /// @return surnameIndex The surname index
    function getNameChangeData(uint256 tokenId) external view returns (uint16 firstNameIndex, uint16 surnameIndex) {
        // Check if token exists by checking if it's been minted
        if (tokenId < 100 || tokenId >= nextNameChangeTokenId) revert TokenDoesNotExist();

        NameData memory data = nameChangeData[tokenId];
        return (data.firstNameIndex, data.surnameIndex);
    }

    /// @notice Burns a ticket from a specific address (requires approval)
    /// @param from Address to burn ticket from
    /// @param tokenId The token ID to burn
    /// @param amount Number of tokens to burn
    function burnFrom(address from, uint256 tokenId, uint256 amount) external {
        if (from != msg.sender && !isApprovedForAll[from][msg.sender]) {
            revert("Not authorized to burn");
        }
        _burn(from, tokenId, amount);
    }

    //==============================================================//
    //                    ADMIN FUNCTIONS                           //
    //==============================================================//
    /// @notice Sets permissions for a game contract
    /// @param gameContract Address of the game contract
    /// @param permissions The permissions to grant
    function setGameContractPermission(address gameContract, GamePermissions calldata permissions) external onlyOwner {
        if (gameContract == address(0)) revert ZeroAddress();
        _gameContractPermissions[gameContract] = permissions;
        emit GameContractPermissionsUpdated(gameContract, permissions);
    }

    /// @notice Gets the permissions for a game contract
    /// @param gameContract Address of the game contract
    /// @return The permissions granted to the contract
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory) {
        return _gameContractPermissions[gameContract];
    }

    //==============================================================//
    //                     INTERNAL HELPERS                         //
    //==============================================================//
    /// @notice Gets the required permission for a ticket type
    /// @param ticketType The ticket type to check
    /// @return The required permission
    function _getRequiredPermission(uint256 ticketType) internal pure returns (TicketPermission) {
        if (ticketType == CREATE_PLAYER_TICKET) return TicketPermission.PLAYER_CREATION;
        if (ticketType == PLAYER_SLOT_TICKET) return TicketPermission.PLAYER_SLOTS;
        if (ticketType == WEAPON_SPECIALIZATION_TICKET) return TicketPermission.WEAPON_SPECIALIZATION;
        if (ticketType == ARMOR_SPECIALIZATION_TICKET) return TicketPermission.ARMOR_SPECIALIZATION;
        if (ticketType == DUEL_TICKET) return TicketPermission.DUELS;
        revert TokenDoesNotExist();
    }
}
