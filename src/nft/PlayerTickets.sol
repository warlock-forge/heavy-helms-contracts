// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "solmate/src/tokens/ERC1155.sol";
import "solmate/src/auth/Owned.sol";

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
    constructor() Owned(msg.sender) {}

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Returns the URI for a given token ID
    /// @param id The token ID to get URI for
    /// @return The URI string
    function uri(uint256 id) public pure override returns (string memory) {
        if (id == CREATE_PLAYER_TICKET) return "ipfs://create-player-ticket";
        if (id == PLAYER_SLOT_TICKET) return "ipfs://player-slot-ticket";
        if (id == WEAPON_SPECIALIZATION_TICKET) return "ipfs://weapon-specialization-ticket";
        if (id == ARMOR_SPECIALIZATION_TICKET) return "ipfs://armor-specialization-ticket";
        if (id == DUEL_TICKET) return "ipfs://duel-ticket";
        if (id >= 100) return "ipfs://name-change-nft";
        return "";
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

    /// @notice Mints a name change NFT with specific name data
    /// @param to Address to mint the NFT to
    /// @param firstNameIndex Index of the first name in the name registry
    /// @param surnameIndex Index of the surname in the name registry
    /// @return tokenId The ID of the newly minted NFT
    function mintNameChangeNFT(address to, uint16 firstNameIndex, uint16 surnameIndex)
        external
        hasPermission(TicketPermission.NAME_CHANGES)
        returns (uint256 tokenId)
    {
        tokenId = nextNameChangeTokenId++;

        // Store the name data
        nameChangeData[tokenId] = NameData({firstNameIndex: firstNameIndex, surnameIndex: surnameIndex});

        // Mint with supply of 1
        _mint(to, tokenId, 1, "");

        emit NameChangeNFTMinted(tokenId, to, firstNameIndex, surnameIndex);
    }

    /// @notice Gets the name data for a name change NFT
    /// @param tokenId The token ID to get name data for
    /// @return firstNameIndex The first name index
    /// @return surnameIndex The surname index
    function getNameChangeData(uint256 tokenId) external view returns (uint16 firstNameIndex, uint16 surnameIndex) {
        NameData memory data = nameChangeData[tokenId];
        if (data.firstNameIndex == 0 && data.surnameIndex == 0) revert TokenDoesNotExist();
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
