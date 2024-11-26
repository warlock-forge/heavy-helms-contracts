// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/src/auth/Owned.sol";
import "solmate/src/tokens/ERC20.sol";

contract PlayerSkinRegistry is Owned {
    struct SkinInfo {
        address contractAddress;
    }

    SkinInfo[] public skins;
    uint256 public registrationFee = 0.001 ether;

    error InsufficientRegistrationFee();
    error NoTokensToCollect();
    error SkinsArrayLimitReached();

    constructor() Owned(msg.sender) {}

    function registerSkin(address contractAddress) external payable returns (uint256) {
        if (msg.sender != owner) {
            if (msg.value < registrationFee) revert InsufficientRegistrationFee();
        }
        if (skins.length >= type(uint32).max) revert SkinsArrayLimitReached();
        skins.push(SkinInfo(contractAddress));
        return skins.length - 1;
    }

    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
    }

    function getSkin(uint256 index) external view returns (SkinInfo memory) {
        require(index < skins.length, "Invalid skin index");
        return skins[index];
    }

    function collect(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) {
            payable(owner).transfer(address(this).balance);
        } else {
            ERC20 token = ERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            if (balance == 0) revert NoTokensToCollect();
            token.transfer(owner, balance);
        }
    }

    receive() external payable {}
}
