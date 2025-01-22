// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import "solmate/src/auth/Owned.sol";
import "solmate/src/tokens/ERC20.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/tokens/ERC721.sol";

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
error SkinNotOwned(address skinContract);
/// @notice Thrown when attempting to set zero address for contract/NFT
error ZeroAddressNotAllowed();

//==============================================================//
//                         HEAVY HELMS                          //
//                     PLAYER SKIN REGISTRY                     //
//==============================================================//
/// @title Player Skin Registry for Heavy Helms
/// @notice Manages registration and verification of player skin collections
contract PlayerSkinRegistry is Owned {
    using SafeTransferLib for ERC20;

    //==============================================================//
    //                     TYPE DECLARATIONS                        //
    //==============================================================//
    /// @notice Information about a registered skin collection
    /// @param contractAddress Address of the skin NFT contract
    /// @param isVerified Whether the collection is verified
    /// @param isDefaultCollection Whether it's a default collection
    /// @param requiredNFTAddress Optional NFT required to use skins
    struct SkinInfo {
        address contractAddress;
        bool isVerified;
        bool isDefaultCollection;
        address requiredNFTAddress;
    }

    //==============================================================//
    //                    STATE VARIABLES                           //
    //==============================================================//
    /// @notice Array of all registered skin collections
    SkinInfo[] public skins;
    /// @notice Fee required to register a new skin collection
    uint256 public registrationFee = 0.005 ether;
    /// @notice Registry ID of the default skin collection
    uint32 public defaultSkinRegistryId;
    /// @notice Next available registry ID for skin collections
    uint32 public nextSkinRegistryId;

    //==============================================================//
    //                          EVENTS                              //
    //==============================================================//
    /// @notice Emitted when a new skin collection is registered
    event SkinRegistered(uint32 indexed registryId, address indexed skinContract);
    /// @notice Emitted when default skin registry is updated
    event DefaultSkinRegistrySet(uint32 indexed registryId);
    /// @notice Emitted when registration fee is updated
    event RegistrationFeeUpdated(uint256 newFee);
    /// @notice Emitted when tokens are collected
    event TokensCollected(address indexed token, uint256 amount);
    /// @notice Emitted when skin verification status changes
    event SkinVerificationUpdated(uint32 indexed registryId, bool isVerified);
    /// @notice Emitted when required NFT is updated
    event RequiredNFTUpdated(uint32 indexed registryId, address requiredNFTAddress);
    /// @notice Emitted when default collection status changes
    event DefaultCollectionUpdated(uint32 indexed registryId, bool isDefault);

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor() Owned(msg.sender) {}

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    /// @notice Registers a new skin collection
    /// @param contractAddress Address of the skin NFT contract
    /// @return Registry ID of the new collection
    function registerSkin(address contractAddress) external payable returns (uint32) {
        if (contractAddress == address(0)) revert ZeroAddressNotAllowed();

        // Check registration fee unless owner
        if (msg.sender != owner) {
            if (msg.value < registrationFee) revert InsufficientRegistrationFee();
        }

        // Register the skin (unverified by default, not default collection)
        skins.push(SkinInfo(contractAddress, false, false, address(0)));
        uint32 registryId = nextSkinRegistryId++;

        emit SkinRegistered(registryId, contractAddress);
        return registryId;
    }

    /// @notice Gets information about a specific skin collection
    /// @param index Registry ID to query
    /// @return SkinInfo struct containing collection details
    function getSkin(uint32 index) external view returns (SkinInfo memory) {
        if (index >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        return skins[index];
    }

    /// @notice Validates ownership of a skin or required NFT
    /// @param skinIndex Registry ID of the skin collection
    /// @param tokenId Token ID of the specific skin
    /// @param owner Address to check ownership for
    function validateSkinOwnership(uint32 skinIndex, uint16 tokenId, address owner) external view {
        if (skinIndex >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        SkinInfo memory skinInfo = skins[skinIndex];

        // Skip validation for default collections
        if (skinInfo.isDefaultCollection) {
            return;
        }

        // If there's a required NFT, ONLY check that they own the required NFT
        if (skinInfo.requiredNFTAddress != address(0)) {
            try ERC721(skinInfo.requiredNFTAddress).balanceOf(owner) returns (uint256 balance) {
                if (balance == 0) {
                    revert RequiredNFTNotOwned(skinInfo.requiredNFTAddress);
                }
            } catch {
                revert RequiredNFTNotOwned(skinInfo.requiredNFTAddress);
            }
        } else {
            // Only check specific token ownership if there's no required NFT
            try ERC721(skinInfo.contractAddress).ownerOf(tokenId) returns (address skinOwner) {
                if (skinOwner != owner) {
                    revert SkinNotOwned(skinInfo.contractAddress);
                }
            } catch {
                revert SkinNotOwned(skinInfo.contractAddress);
            }
        }
    }

    /// @notice Gets all verified skin collections
    /// @return Array of verified SkinInfo structs
    function getVerifiedSkins() external view returns (SkinInfo[] memory) {
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
            SkinInfo[] memory result = new SkinInfo[](verifiedCount);
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
            SafeTransferLib.safeTransferETH(owner, balance);
            emit TokensCollected(address(0), balance);
        } else {
            ERC20 token = ERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            if (balance == 0) revert NoTokensToCollect();
            token.safeTransfer(owner, balance);
            emit TokensCollected(tokenAddress, balance);
        }
    }

    /// @notice Updates verification status of a skin collection
    /// @param registryId Registry ID to update
    /// @param isVerified New verification status
    function setSkinVerification(uint32 registryId, bool isVerified) external onlyOwner {
        if (registryId >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        skins[registryId].isVerified = isVerified;
        emit SkinVerificationUpdated(registryId, isVerified);
    }

    /// @notice Sets required NFT for a skin collection
    /// @param registryId Registry ID to update
    /// @param requiredNFTAddress Address of required NFT (can be zero to remove requirement)
    function setRequiredNFT(uint32 registryId, address requiredNFTAddress) external onlyOwner {
        if (registryId >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();

        // No zero address check here as it's valid to set to zero to remove requirement
        skins[registryId].requiredNFTAddress = requiredNFTAddress;
        emit RequiredNFTUpdated(registryId, requiredNFTAddress);
    }

    /// @notice Updates default collection status
    /// @param registryId Registry ID to update
    /// @param isDefault New default collection status
    function setDefaultCollection(uint32 registryId, bool isDefault) external onlyOwner {
        if (registryId >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        skins[registryId].isDefaultCollection = isDefault;
        emit DefaultCollectionUpdated(registryId, isDefault);
    }

    /// @notice Sets the default skin collection
    /// @param _id Registry ID to set as default
    function setDefaultSkinRegistryId(uint32 _id) external onlyOwner {
        if (_id >= nextSkinRegistryId) revert InvalidDefaultSkinRegistry();
        defaultSkinRegistryId = _id;
        emit DefaultSkinRegistrySet(_id);
    }

    /// @notice Updates the registration fee
    /// @param newFee New fee amount in wei
    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
        emit RegistrationFeeUpdated(newFee);
    }

    /// @notice Allows contract to receive ETH
    receive() external payable {}
}
