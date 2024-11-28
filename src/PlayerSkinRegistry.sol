// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "solmate/src/tokens/ERC20.sol";

contract PlayerSkinRegistry is Owned {
    struct SkinInfo {
        address contractAddress;
    }

    // State Variables
    SkinInfo[] public skins;
    uint256 public registrationFee = 0.001 ether;
    uint32 public defaultSkinRegistryId;
    uint32 public nextSkinRegistryId;
    address public immutable playerContract;

    // Events
    event SkinRegistered(uint32 indexed registryId, address indexed skinContract);
    event DefaultSkinRegistrySet(uint32 indexed registryId);
    event RegistrationFeeUpdated(uint256 newFee);
    event TokensCollected(address indexed token, uint256 amount);

    // Errors
    error InsufficientRegistrationFee();
    error NoTokensToCollect();
    error SkinsArrayLimitReached();
    error InvalidDefaultSkinRegistry();
    error SkinRegistryDoesNotExist();

    constructor(address _playerContract) Owned(msg.sender) {
        playerContract = _playerContract;
    }

    function registerSkin(address contractAddress) external payable returns (uint32) {
        // Check registration fee unless owner
        if (msg.sender != owner) {
            if (msg.value < registrationFee) revert InsufficientRegistrationFee();
        }

        // Check array limits
        if (nextSkinRegistryId >= type(uint32).max) revert SkinsArrayLimitReached();

        // Register the skin
        skins.push(SkinInfo(contractAddress));
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
            payable(owner).transfer(balance);
            emit TokensCollected(address(0), balance);
        } else {
            ERC20 token = ERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            if (balance == 0) revert NoTokensToCollect();
            token.transfer(owner, balance);
            emit TokensCollected(tokenAddress, balance);
        }
    }

    receive() external payable {}
}
