// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "solmate/src/tokens/ERC20.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/tokens/ERC721.sol";

contract PlayerSkinRegistry is Owned {
    using SafeTransferLib for ERC20;

    struct SkinInfo {
        address contractAddress;
        bool isVerified;
        bool isDefaultCollection;
        address requiredNFTAddress;
    }

    // State Variables
    SkinInfo[] public skins;
    uint256 public registrationFee = 0.001 ether;
    uint32 public defaultSkinRegistryId;
    uint32 public nextSkinRegistryId;

    // Events
    event SkinRegistered(uint32 indexed registryId, address indexed skinContract);
    event DefaultSkinRegistrySet(uint32 indexed registryId);
    event RegistrationFeeUpdated(uint256 newFee);
    event TokensCollected(address indexed token, uint256 amount);
    event SkinVerificationUpdated(uint32 indexed registryId, bool isVerified);
    event RequiredNFTUpdated(uint32 indexed registryId, address requiredNFTAddress);
    event DefaultCollectionUpdated(uint32 indexed registryId, bool isDefault);

    // Errors
    error InsufficientRegistrationFee();
    error NoTokensToCollect();
    error SkinsArrayLimitReached();
    error InvalidDefaultSkinRegistry();
    error SkinRegistryDoesNotExist();
    error RequiredNFTNotOwned(address nftAddress);
    error SkinNotOwned(address skinContract);

    constructor() Owned(msg.sender) {}

    function registerSkin(address contractAddress) external payable returns (uint32) {
        // Check registration fee unless owner
        if (msg.sender != owner) {
            if (msg.value < registrationFee) revert InsufficientRegistrationFee();
        }

        // Check array limits
        if (nextSkinRegistryId >= type(uint32).max) revert SkinsArrayLimitReached();

        // Register the skin (unverified by default, not default collection)
        skins.push(SkinInfo(contractAddress, false, false, address(0)));
        uint32 registryId = nextSkinRegistryId++;

        emit SkinRegistered(registryId, contractAddress);
        return registryId;
    }

    function setDefaultSkinRegistryId(uint32 _id) external onlyOwner {
        // Verify the registry ID exists
        if (_id >= nextSkinRegistryId) revert InvalidDefaultSkinRegistry();
        defaultSkinRegistryId = _id;
        emit DefaultSkinRegistrySet(_id);
    }

    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
        emit RegistrationFeeUpdated(newFee);
    }

    function getSkin(uint32 index) external view returns (SkinInfo memory) {
        if (index >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        return skins[index];
    }

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

    function setSkinVerification(uint32 registryId, bool isVerified) external onlyOwner {
        if (registryId >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        skins[registryId].isVerified = isVerified;
        emit SkinVerificationUpdated(registryId, isVerified);
    }

    function setRequiredNFT(uint32 registryId, address requiredNFTAddress) external onlyOwner {
        if (registryId >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        skins[registryId].requiredNFTAddress = requiredNFTAddress;
        emit RequiredNFTUpdated(registryId, requiredNFTAddress);
    }

    function getVerifiedSkins() external view returns (SkinInfo[] memory) {
        // First, count verified skins
        uint256 verifiedCount = 0;
        for (uint256 i = 0; i < skins.length; i++) {
            if (skins[i].isVerified) {
                verifiedCount++;
            }
        }

        // Create and populate array of verified skins
        SkinInfo[] memory verifiedSkins = new SkinInfo[](verifiedCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < skins.length; i++) {
            if (skins[i].isVerified) {
                verifiedSkins[currentIndex] = skins[i];
                currentIndex++;
            }
        }

        return verifiedSkins;
    }

    function setDefaultCollection(uint32 registryId, bool isDefault) external onlyOwner {
        if (registryId >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        skins[registryId].isDefaultCollection = isDefault;
        emit DefaultCollectionUpdated(registryId, isDefault);
    }

    function validateSkinOwnership(uint32 skinIndex, uint16 tokenId, address owner) external view {
        if (skinIndex >= nextSkinRegistryId) revert SkinRegistryDoesNotExist();
        SkinInfo memory skinInfo = skins[skinIndex];
        if (!skinInfo.isDefaultCollection) {
            // If there's a required NFT, check that they own at least one
            if (skinInfo.requiredNFTAddress != address(0)) {
                try ERC721(skinInfo.requiredNFTAddress).balanceOf(owner) returns (uint256 balance) {
                    if (balance == 0) {
                        revert RequiredNFTNotOwned(skinInfo.requiredNFTAddress);
                    }
                } catch {
                    revert RequiredNFTNotOwned(skinInfo.requiredNFTAddress);
                }
            } else {
                // If no required NFT (address(0)), then check actual skin ownership
                try ERC721(skinInfo.contractAddress).ownerOf(tokenId) returns (address skinOwner) {
                    if (skinOwner != owner) {
                        revert SkinNotOwned(skinInfo.contractAddress);
                    }
                } catch {
                    revert SkinNotOwned(skinInfo.contractAddress);
                }
            }
        }
    }

    receive() external payable {}
}
