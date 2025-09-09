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
import {ERC1155} from "solady/tokens/ERC1155.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IPlayerNameRegistry} from "../interfaces/fighters/registries/names/IPlayerNameRegistry.sol";
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
/// @notice Thrown when attempting to transfer a soulbound token
error TokenNotTransferable();

//==============================================================//
//                         HEAVY HELMS                          //
//                       PLAYER TICKETS                         //
//==============================================================//
/// @title Player Tickets for Heavy Helms
/// @notice Manages both fungible utility tickets and non-fungible name change NFTs
/// @dev All tickets are tradeable on OpenSea except soulbound tokens
contract PlayerTickets is ERC1155, ConfirmedOwner {
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
        DUELS,
        DAILY_RESETS,
        ATTRIBUTE_SWAPS
    }

    //==============================================================//
    //                          STRUCTS                             //
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
        bool dailyResets;
        bool attributeSwaps;
    }

    //==============================================================//
    //                      STATE VARIABLES                         //
    //==============================================================//
    // --- Token ID Constants ---
    /// @notice Fungible ticket IDs (1-99)
    uint256 public constant CREATE_PLAYER_TICKET = 1;
    uint256 public constant PLAYER_SLOT_TICKET = 2;
    uint256 public constant WEAPON_SPECIALIZATION_TICKET = 3;
    uint256 public constant ARMOR_SPECIALIZATION_TICKET = 4;
    uint256 public constant DUEL_TICKET = 5;
    uint256 public constant DAILY_RESET_TICKET = 6;
    uint256 public constant ATTRIBUTE_SWAP_TICKET = 7;

    // --- Dynamic Variables ---
    /// @notice Non-fungible name change NFTs start at 100
    uint256 public nextNameChangeTokenId = 100;
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
        _checkPermission(permission);
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor(address nameRegistryAddress) ConfirmedOwner(msg.sender) {
        if (nameRegistryAddress == address(0)) revert ZeroAddress();
        _nameRegistry = IPlayerNameRegistry(nameRegistryAddress);
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Override safeTransferFrom to block soulbound token transfers
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        virtual
        override
    {
        if (_isSoulbound(id)) revert TokenNotTransferable();
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /// @notice Override safeBatchTransferFrom to block soulbound token transfers
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual override {
        uint256 idLength = ids.length;
        for (uint256 i = 0; i < idLength; i++) {
            if (_isSoulbound(ids[i])) revert TokenNotTransferable();
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /// @notice Returns the URI for a given token ID
    /// @param id The token ID to get URI for
    /// @return The URI string
    function uri(uint256 id) public view override returns (string memory) {
        if (id == CREATE_PLAYER_TICKET) return _generateCreatePlayerURI();
        if (id == PLAYER_SLOT_TICKET) return _generatePlayerSlotURI();
        if (id == WEAPON_SPECIALIZATION_TICKET) return _generateWeaponSpecURI();
        if (id == ARMOR_SPECIALIZATION_TICKET) return _generateArmorSpecURI();
        if (id == DUEL_TICKET) return _generateDuelTicketURI();
        if (id == DAILY_RESET_TICKET) return _generateDailyResetURI();
        if (id == ATTRIBUTE_SWAP_TICKET) return _generateAttributeSwapURI();
        if (id >= 100) return _generateNameChangeURI(id);
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

    /// @notice Gets the permissions for a game contract
    /// @param gameContract Address of the game contract
    /// @return The permissions granted to the contract
    function gameContractPermissions(address gameContract) external view returns (GamePermissions memory) {
        return _gameContractPermissions[gameContract];
    }

    /// @notice Burns a ticket from a specific address (requires approval)
    /// @param from Address to burn ticket from
    /// @param tokenId The token ID to burn
    /// @param amount Number of tokens to burn
    function burnFrom(address from, uint256 tokenId, uint256 amount) external {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
            revert("Not authorized to burn");
        }
        _burn(from, tokenId, amount);
    }

    /// @notice Mints fungible tickets with gas-limited callback to prevent DoS
    /// @param to Address to mint tickets to
    /// @param ticketType The type of ticket to mint
    /// @param amount Number of tickets to mint
    function mintFungibleTicketSafe(address to, uint256 ticketType, uint256 amount)
        external
        hasPermission(_getRequiredPermission(ticketType))
    {
        _mint(to, ticketType, amount, "");
    }

    /// @notice Mints a name change NFT with gas-limited callback to prevent DoS
    /// @param to Address to mint the NFT to
    /// @param seed External seed to ensure admin cannot cherry-pick names
    /// @return tokenId The ID of the newly minted NFT
    function mintNameChangeNFTSafe(address to, uint256 seed)
        external
        hasPermission(TicketPermission.NAME_CHANGES)
        returns (uint256 tokenId)
    {
        // Same logic as mintNameChangeNFT but with gas-limited mint
        uint256 entropy = uint256(
            keccak256(
                abi.encode(seed, block.timestamp, block.prevrandao, to, nextNameChangeTokenId, address(this).balance)
            )
        );

        uint16 setBLength = _nameRegistry.getNameSetBLength();
        uint16 setALength = _nameRegistry.getNameSetALength();
        uint16 surnameLength = _nameRegistry.getSurnamesLength();
        uint256 totalFirstNames = uint256(setALength) + uint256(setBLength);

        uint256 firstNameRandom = entropy % totalFirstNames;
        uint16 firstNameIndex;

        if (firstNameRandom < setBLength) {
            firstNameIndex = uint16(firstNameRandom);
        } else {
            firstNameIndex = _nameRegistry.getSetAStart() + uint16(firstNameRandom - setBLength);
        }

        uint16 surnameIndex = uint16((entropy >> 128) % surnameLength);

        tokenId = nextNameChangeTokenId++;
        nameChangeData[tokenId] = NameData({firstNameIndex: firstNameIndex, surnameIndex: surnameIndex});
        _mint(to, tokenId, 1, "");

        emit NameChangeNFTMinted(tokenId, to, firstNameIndex, surnameIndex);
    }

    /// @dev Override Solady's _mint to use gas-limited callback
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal override {
        /// @solidity memory-safe-assembly
        assembly {
            let to_ := shl(96, to)
            // Revert if `to` is the zero address.
            if iszero(to_) {
                mstore(0x00, 0xea553b34) // `TransferToZeroAddress()`.
                revert(0x1c, 0x04)
            }
            // Increase and store the updated balance of `to`.
            {
                mstore(0x20, 0x9a31110384e0b0c9) // _ERC1155_MASTER_SLOT_SEED
                mstore(0x14, to)
                mstore(0x00, id)
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) // `AccountBalanceOverflow()`.
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            // Emit a {TransferSingle} event.
            mstore(0x20, amount)
            log4(
                0x00,
                0x40,
                0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62,
                caller(),
                0,
                shr(96, to_)
            )
        }
        // Check if contract and call with gas limit
        if (_hasCodeHelper(to)) _checkOnERC1155ReceivedGasLimited(address(0), to, id, amount, data);
    }

    /// @dev Gas-limited version of _checkOnERC1155Received with 50000 gas limit
    function _checkOnERC1155ReceivedGasLimited(address from, address to, uint256 id, uint256 amount, bytes memory data)
        private
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the calldata.
            let m := mload(0x40)
            let dataLength := mload(data)
            // `onERC1155Received(address,address,uint256,uint256,bytes)`.
            mstore(m, 0xf23a6e61)
            mstore(add(m, 0x20), caller())
            mstore(add(m, 0x40), from)
            mstore(add(m, 0x60), id)
            mstore(add(m, 0x80), amount)
            mstore(add(m, 0xa0), 0xa0)
            mstore(add(m, 0xc0), dataLength)
            let dataPtr := add(data, 0x20)
            if dataLength {
                // Use identity precompile to copy data
                pop(staticcall(gas(), 0x04, dataPtr, dataLength, add(m, 0xe0), dataLength))
            }
            // CHANGED: Limit gas to 50000 instead of gas()
            if iszero(call(50000, to, 0, add(m, 0x1c), add(0xc4, dataLength), m, 0x20)) {
                if returndatasize() {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(m, 0x00, returndatasize())
                    revert(m, returndatasize())
                }
            }
            // Load the returndata and compare it with the function selector.
            if iszero(eq(mload(m), shl(224, 0xf23a6e61))) {
                mstore(0x00, 0x9c05499b) // `TransferToNonERC1155ReceiverImplementer()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns if `a` has bytecode of non-zero length.
    function _hasCodeHelper(address a) private view returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := extcodesize(a) // Can handle dirty upper bits.
        }
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

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
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
        if (ticketType == DAILY_RESET_TICKET) return TicketPermission.DAILY_RESETS;
        if (ticketType == ATTRIBUTE_SWAP_TICKET) return TicketPermission.ATTRIBUTE_SWAPS;
        revert TokenDoesNotExist();
    }

    /// @notice Checks if a token ID represents a soulbound token
    /// @param tokenId The token ID to check
    /// @return True if the token is soulbound (non-transferable)
    function _isSoulbound(uint256 tokenId) internal pure returns (bool) {
        return tokenId == ATTRIBUTE_SWAP_TICKET;
    }

    /// @notice Internal method to validate caller has required ticket permission
    /// @param permission The permission type to check
    /// @dev Reverts with NotAuthorizedToMint if the caller lacks the required permission
    function _checkPermission(TicketPermission permission) internal view {
        if (msg.sender != owner()) {
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
            } else if (permission == TicketPermission.DAILY_RESETS) {
                hasRequiredPermission = permissions.dailyResets;
            } else if (permission == TicketPermission.ATTRIBUTE_SWAPS) {
                hasRequiredPermission = permissions.attributeSwaps;
            }

            if (!hasRequiredPermission) revert NotAuthorizedToMint();
        }
    }

    /// @notice Generates SVG-based URI for Create Player ticket
    function _generateCreatePlayerURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Utility Ticket</text>',
                '<text x="200" y="200" text-anchor="middle" fill="#4169E1" font-size="24" font-family="serif" font-weight="bold" filter="url(#glow)">CREATE PLAYER</text>',
                unicode'<text x="200" y="240" text-anchor="middle" fill="white" font-size="48">⚔️</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#4169E1" font-size="14" font-family="serif">RARE TICKET</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Player Creation Ticket",',
                '"description":"Allows creation of a new warrior in Heavy Helms. Burn this ticket to bypass the ETH creation fee and mint your warrior.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"Item Type","value":"Ticket"},',
                '{"trait_type":"Rarity","value":"Rare"},',
                '{"trait_type":"Effect","value":"Create Player"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Generates SVG-based URI for Player Slot ticket
    function _generatePlayerSlotURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Utility Ticket</text>',
                '<text x="200" y="200" text-anchor="middle" fill="#32CD32" font-size="24" font-family="serif" font-weight="bold" filter="url(#glow)">PLAYER SLOT</text>',
                unicode'<text x="200" y="240" text-anchor="middle" fill="white" font-size="48">📦</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#32CD32" font-size="14" font-family="serif">UNCOMMON TICKET</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Player Slot Ticket",',
                '"description":"Grants an additional player slot in Heavy Helms. Burn this ticket to expand your warrior roster capacity.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"Item Type","value":"Ticket"},',
                '{"trait_type":"Rarity","value":"Uncommon"},',
                '{"trait_type":"Effect","value":"Add Player Slot"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Generates SVG-based URI for Weapon Specialization ticket
    function _generateWeaponSpecURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Utility Ticket</text>',
                '<text x="200" y="190" text-anchor="middle" fill="#C0C0C0" font-size="22" font-family="serif" font-weight="bold" filter="url(#glow)">WEAPON</text>',
                '<text x="200" y="220" text-anchor="middle" fill="#C0C0C0" font-size="22" font-family="serif" font-weight="bold" filter="url(#glow)">SPECIALIZATION</text>',
                unicode'<text x="200" y="260" text-anchor="middle" fill="white" font-size="48">🗡️</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#C0C0C0" font-size="14" font-family="serif">COMMON TICKET</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Weapon Specialization Ticket",',
                '"description":"Allows a warrior to respecialize their weapon mastery. Burn this ticket to change weapon specialization. Initial specialization is free.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"Item Type","value":"Ticket"},',
                '{"trait_type":"Rarity","value":"Common"},',
                '{"trait_type":"Effect","value":"Respec Weapon"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Generates SVG-based URI for Armor Specialization ticket
    function _generateArmorSpecURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Utility Ticket</text>',
                '<text x="200" y="190" text-anchor="middle" fill="#C0C0C0" font-size="22" font-family="serif" font-weight="bold" filter="url(#glow)">ARMOR</text>',
                '<text x="200" y="220" text-anchor="middle" fill="#C0C0C0" font-size="22" font-family="serif" font-weight="bold" filter="url(#glow)">SPECIALIZATION</text>',
                unicode'<text x="200" y="260" text-anchor="middle" fill="white" font-size="48">🛡️</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#C0C0C0" font-size="14" font-family="serif">COMMON TICKET</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Armor Specialization Ticket",',
                '"description":"Allows a warrior to respecialize their armor expertise. Burn this ticket to change armor specialization. Initial specialization is free.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"Item Type","value":"Ticket"},',
                '{"trait_type":"Rarity","value":"Common"},',
                '{"trait_type":"Effect","value":"Respec Armor"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Generates SVG-based URI for Duel ticket
    function _generateDuelTicketURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Utility Ticket</text>',
                '<text x="200" y="200" text-anchor="middle" fill="#C0C0C0" font-size="24" font-family="serif" font-weight="bold" filter="url(#glow)">DUEL TICKET</text>',
                unicode'<text x="200" y="240" text-anchor="middle" fill="white" font-size="48">⚔️</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#C0C0C0" font-size="14" font-family="serif">COMMON TICKET</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Duel Ticket",',
                '"description":"Grants entry to a duel match in Heavy Helms. Burn this ticket to challenge another warrior in single combat.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"Item Type","value":"Ticket"},',
                '{"trait_type":"Rarity","value":"Common"},',
                '{"trait_type":"Effect","value":"Start Duel"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Returns common SVG definitions used across all tickets
    function _getCommonSVGDefs() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<defs>",
                '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
                '<stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />',
                '<stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />',
                "</linearGradient>",
                '<filter id="glow">',
                '<feGaussianBlur stdDeviation="3" result="coloredBlur"/>',
                '<feMerge><feMergeNode in="coloredBlur"/><feMergeNode in="SourceGraphic"/></feMerge>',
                "</filter>",
                "</defs>"
            )
        );
    }

    /// @notice Generates SVG-based URI for Daily Reset ticket
    function _generateDailyResetURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Utility Ticket</text>',
                '<text x="200" y="180" text-anchor="middle" fill="#C0C0C0" font-size="24" font-family="serif" font-weight="bold" filter="url(#glow)">DAILY RESET</text>',
                '<text x="200" y="210" text-anchor="middle" fill="#C0C0C0" font-size="24" font-family="serif" font-weight="bold" filter="url(#glow)">TICKET</text>',
                unicode'<text x="200" y="260" text-anchor="middle" fill="white" font-size="48">🔄</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#888" font-size="12" font-family="sans-serif">Resets daily gauntlet cooldown</text>',
                '<text x="200" y="340" text-anchor="middle" fill="#888" font-size="12" font-family="sans-serif">Single use - burns on consumption</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Daily Reset Ticket","description":"A utility ticket that allows immediate reset of daily gauntlet cooldown. Burns on use.","image":"',
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svg)),
                '","attributes":[',
                '{"trait_type":"Type","value":"Utility Ticket"},',
                '{"trait_type":"Effect","value":"Daily Reset"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @notice Generates SVG-based URI for Attribute Swap ticket
    function _generateAttributeSwapURI() internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
                _getCommonSVGDefs(),
                '<rect width="400" height="400" fill="url(#bg)"/>',
                '<rect x="20" y="20" width="360" height="360" fill="none" stroke="gold" stroke-width="3" rx="20"/>',
                '<text x="200" y="80" text-anchor="middle" fill="gold" font-size="18" font-family="serif" font-weight="bold">HEAVY HELMS</text>',
                '<text x="200" y="110" text-anchor="middle" fill="white" font-size="14" font-family="serif">Soulbound Ticket</text>',
                '<text x="200" y="180" text-anchor="middle" fill="#FF6B6B" font-size="22" font-family="serif" font-weight="bold" filter="url(#glow)">ATTRIBUTE</text>',
                '<text x="200" y="210" text-anchor="middle" fill="#FF6B6B" font-size="22" font-family="serif" font-weight="bold" filter="url(#glow)">SWAP</text>',
                unicode'<text x="200" y="260" text-anchor="middle" fill="white" font-size="48">⚖️</text>',
                '<text x="200" y="320" text-anchor="middle" fill="#FF6B6B" font-size="14" font-family="serif">LEGENDARY TICKET</text>',
                '<text x="200" y="340" text-anchor="middle" fill="#888" font-size="10" font-family="serif">NON-TRANSFERABLE</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{"name":"Attribute Swap Ticket",',
                '"description":"Allows swapping one attribute point between stats. This is a soulbound token that cannot be transferred or sold. Burn this ticket to swap attributes.",',
                '"image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '",',
                '"attributes":[',
                '{"trait_type":"Item Type","value":"Soulbound Ticket"},',
                '{"trait_type":"Rarity","value":"Legendary"},',
                '{"trait_type":"Effect","value":"Swap Attributes"},',
                '{"trait_type":"Transferable","value":"No"},',
                '{"trait_type":"Burn Type","value":"On Use"}',
                "]}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
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
}
