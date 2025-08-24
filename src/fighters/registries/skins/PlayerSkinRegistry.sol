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
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import "../../../interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import "../../../interfaces/nft/skins/IPlayerSkinNFT.sol";
import "../../Fighter.sol";
import "../../../interfaces/game/engine/IGameEngine.sol";
import "../../../interfaces/game/engine/IEquipmentRequirements.sol";
//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//

/// @notice Thrown when registration fee is insufficient
error InsufficientRegistrationFee();
/// @notice Thrown when attempting to collect with zero balance
error NoTokensToCollect();
/// @notice Thrown when setting invalid default skin registry
error InvalidDefaultSkinRegistry();
/// @notice Thrown when accessing non-existent skin registry
error SkinRegistryDoesNotExist();
/// @notice Thrown when user doesn't own required NFT
error RequiredNFTNotOwned(address nftAddress);
/// @notice Thrown when user doesn't own specific skin
error SkinNotOwned(address skinContract, uint16 tokenId);
/// @notice Thrown when attempting to set zero address for contract/NFT
error ZeroAddressNotAllowed();
/// @notice Thrown when attempting to validate a skin of an invalid type
error InvalidSkinType();
/// @notice Thrown when equipment requirements are not met
error EquipmentRequirementsNotMet();

//==============================================================//
//                         HEAVY HELMS                          //
//                     PLAYER SKIN REGISTRY                     //
//==============================================================//
/// @title Player Skin Registry for Heavy Helms
/// @notice Manages registration and verification of player skin collections
contract PlayerSkinRegistry is IPlayerSkinRegistry, ConfirmedOwner {
    using SafeTransferLib for ERC20;

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Array of all registered skin collections
    SkinCollectionInfo[] public skins;
    /// @notice Fee required to register a new skin collection
    uint256 public registrationFee = 0.005 ether;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new skin collection is registered
    event SkinRegistered(uint32 indexed registryId, address indexed skinContract);
    /// @notice Emitted when registration fee is updated
    event RegistrationFeeUpdated(uint256 newFee);
    /// @notice Emitted when tokens are collected
    event TokensCollected(address indexed token, uint256 amount);
    /// @notice Emitted when skin verification status changes
    event SkinVerificationUpdated(uint32 indexed registryId, bool isVerified);
    /// @notice Emitted when required NFT is updated
    event RequiredNFTUpdated(uint32 indexed registryId, address requiredNFTAddress);
    /// @notice Emitted when skin type is updated
    event SkinTypeUpdated(uint32 indexed registryId, SkinType skinType);

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor() ConfirmedOwner(msg.sender) {}

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Registers a new skin collection
    /// @param contractAddress Address of the skin NFT contract
    /// @return Registry ID of the new collection
    function registerSkin(address contractAddress) external payable returns (uint32) {
        if (contractAddress == address(0)) revert ZeroAddressNotAllowed();

        // Check registration fee unless owner
        if (msg.sender != owner()) {
            if (msg.value < registrationFee) revert InsufficientRegistrationFee();
        }

        // Register the skin (unverified by default, Player type by default)
        skins.push(
            SkinCollectionInfo({
                contractAddress: contractAddress,
                isVerified: false,
                skinType: SkinType.Player,
                requiredNFTAddress: address(0)
            })
        );
        uint32 registryId = uint32(skins.length - 1);

        emit SkinRegistered(registryId, contractAddress);
        return registryId;
    }

    /// @notice Gets information about a specific skin collection
    /// @param index Registry ID to query
    /// @return SkinCollectionInfo struct containing collection details
    function getSkin(uint32 index) external view returns (SkinCollectionInfo memory) {
        if (index >= skins.length) revert SkinRegistryDoesNotExist();
        return skins[index];
    }

    /// @notice Validates ownership of a skin or required NFT
    /// @param skin The skin information (index and token ID)
    /// @param owner Address to check ownership for
    function validateSkinOwnership(Fighter.SkinInfo memory skin, address owner) external view {
        if (skin.skinIndex >= skins.length) {
            revert SkinRegistryDoesNotExist();
        }

        SkinCollectionInfo memory skinCollectionInfo = skins[skin.skinIndex];

        // Case 1: Default player skin - anyone can equip
        if (skinCollectionInfo.skinType == SkinType.DefaultPlayer) {
            return;
        }

        // Case 2: Monster skin - never allowed
        if (skinCollectionInfo.skinType == SkinType.Monster) {
            revert InvalidSkinType();
        }

        // Case 3: Collection with required NFT
        if (skinCollectionInfo.requiredNFTAddress != address(0)) {
            if (ERC721(skinCollectionInfo.requiredNFTAddress).balanceOf(owner) == 0) {
                revert RequiredNFTNotOwned(skinCollectionInfo.requiredNFTAddress);
            }
        }
        // Case 4: Regular collection - check specific token ownership
        else {
            IPlayerSkinNFT skinContract = IPlayerSkinNFT(skinCollectionInfo.contractAddress);
            if (skinContract.ownerOf(skin.skinTokenId) != owner) {
                revert SkinNotOwned(skinCollectionInfo.contractAddress, skin.skinTokenId);
            }
        }
    }

    /// @notice Gets all verified skin collections
    /// @return Array of verified SkinCollectionInfo structs
    function getVerifiedSkins() external view returns (SkinCollectionInfo[] memory) {
        unchecked {
            uint256 len = skins.length;

            // Count verified skins in one pass
            uint256 verifiedCount = 0;
            for (uint256 i = 0; i < len; i++) {
                if (skins[i].isVerified) {
                    verifiedCount++;
                }
            }

            // Create correctly sized array and fill it
            SkinCollectionInfo[] memory result = new SkinCollectionInfo[](verifiedCount);
            uint256 currentIndex = 0;
            for (uint256 i = 0; i < len; i++) {
                if (skins[i].isVerified) {
                    result[currentIndex++] = skins[i];
                }
            }

            return result;
        }
    }

    /// @notice Collects accumulated fees or tokens
    /// @param tokenAddress Address of token to collect (0 for ETH)
    function collect(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) {
            uint256 balance = address(this).balance;
            if (balance == 0) revert NoTokensToCollect();
            SafeTransferLib.safeTransferETH(owner(), balance);
            emit TokensCollected(address(0), balance);
        } else {
            ERC20 token = ERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            if (balance == 0) revert NoTokensToCollect();
            SafeTransferLib.safeTransfer(tokenAddress, owner(), balance);
            emit TokensCollected(tokenAddress, balance);
        }
    }

    /// @notice Updates verification status of a skin collection
    /// @param registryId Registry ID to update
    /// @param isVerified New verification status
    function setSkinVerification(uint32 registryId, bool isVerified) external onlyOwner {
        if (registryId >= skins.length) revert SkinRegistryDoesNotExist();
        skins[registryId].isVerified = isVerified;
        emit SkinVerificationUpdated(registryId, isVerified);
    }

    /// @notice Sets required NFT for a skin collection
    /// @param registryId Registry ID to update
    /// @param requiredNFTAddress Address of required NFT (can be zero to remove requirement)
    function setRequiredNFT(uint32 registryId, address requiredNFTAddress) external onlyOwner {
        if (registryId >= skins.length) revert SkinRegistryDoesNotExist();

        // No zero address check here as it's valid to set to zero to remove requirement
        skins[registryId].requiredNFTAddress = requiredNFTAddress;
        emit RequiredNFTUpdated(registryId, requiredNFTAddress);
    }

    /// @notice Updates the registration fee
    /// @param newFee New fee amount in wei
    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
        emit RegistrationFeeUpdated(newFee);
    }

    /// @notice Updates the skin type of a skin collection
    /// @param registryId Registry ID to update
    /// @param skinType New skin type
    function setSkinType(uint32 registryId, SkinType skinType) external onlyOwner {
        if (registryId >= skins.length) {
            revert SkinRegistryDoesNotExist();
        }
        skins[registryId].skinType = skinType;
        emit SkinTypeUpdated(registryId, skinType);
    }

    /// @notice Validates skin requirements
    /// @param skin The skin information (index and token ID)
    /// @param attributes The attributes of the player
    /// @param equipmentRequirements The EquipmentRequirements contract
    function validateSkinRequirements(
        Fighter.SkinInfo memory skin,
        Fighter.Attributes memory attributes,
        IEquipmentRequirements equipmentRequirements
    ) external view {
        if (skin.skinIndex >= skins.length) {
            revert SkinRegistryDoesNotExist();
        }

        SkinCollectionInfo memory skinCollectionInfo = skins[skin.skinIndex];

        // Monster skins have their own validation
        if (skinCollectionInfo.skinType == SkinType.Monster) {
            return;
        }

        // Get skin attributes
        IPlayerSkinNFT skinContract = IPlayerSkinNFT(skinCollectionInfo.contractAddress);
        IPlayerSkinNFT.SkinAttributes memory skinAttrs = skinContract.getSkinAttributes(skin.skinTokenId);

        // Get requirements from EquipmentRequirements
        Fighter.Attributes memory weaponReqs = equipmentRequirements.getWeaponRequirements(skinAttrs.weapon);
        Fighter.Attributes memory armorReqs = equipmentRequirements.getArmorRequirements(skinAttrs.armor);

        // Check all requirements at once
        if (
            attributes.strength < weaponReqs.strength || attributes.constitution < weaponReqs.constitution
                || attributes.size < weaponReqs.size || attributes.agility < weaponReqs.agility
                || attributes.stamina < weaponReqs.stamina || attributes.luck < weaponReqs.luck
                || attributes.strength < armorReqs.strength || attributes.constitution < armorReqs.constitution
                || attributes.size < armorReqs.size || attributes.agility < armorReqs.agility
                || attributes.stamina < armorReqs.stamina || attributes.luck < armorReqs.luck
        ) {
            revert EquipmentRequirementsNotMet();
        }
    }

    /// @notice Allows contract to receive ETH
    receive() external payable {}
}
