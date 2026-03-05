// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    PlayerSkinNFT,
    TokenDoesNotExist,
    InvalidBaseURI,
    MaxSupplyReached,
    InvalidTokenId,
    InvalidMintPrice,
    MintingDisabled
} from "../../src/nft/skins/PlayerSkinNFT.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/nft/skins/IPlayerSkinNFT.sol";

contract PlayerSkinNFTTest is Test {
    receive() external payable {}

    PlayerSkinNFT public nft;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    uint256 public constant MINT_PRICE = 0.01 ether;

    function setUp() public {
        nft = new PlayerSkinNFT("Test Skins", "TSKIN", MINT_PRICE);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // --- Constructor ---

    function testConstructorState() public view {
        assertEq(nft.name(), "Test Skins");
        assertEq(nft.symbol(), "TSKIN");
        assertEq(nft.MAX_SUPPLY(), 10000);
        assertEq(nft.CURRENT_TOKEN_ID(), 1);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertFalse(nft.mintingEnabled());
    }

    // --- Owner Mint (free) ---

    function testMintSkinAsOwner() public {
        uint16 tokenId = nft.mintSkin(user1, 3, 2);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.CURRENT_TOKEN_ID(), 2);

        IPlayerSkinNFT.SkinAttributes memory attrs = nft.getSkinAttributes(1);
        assertEq(attrs.weapon, 3);
        assertEq(attrs.armor, 2);
    }

    function testOwnerMintsFreeWithoutMintingEnabled() public {
        // Owner can mint even when minting is disabled, for free
        uint16 tokenId = nft.mintSkin(user1, 0, 0);
        assertEq(tokenId, 1);
    }

    // --- Public Mint (paid) ---

    function testMintSkinAsPublic() public {
        nft.setMintingEnabled(true);

        vm.prank(user1);
        uint16 tokenId = nft.mintSkin{value: MINT_PRICE}(user1, 5, 1);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(1), user1);
    }

    function testRevertWhen_PublicMintDisabled() public {
        vm.expectRevert(MintingDisabled.selector);
        vm.prank(user1);
        nft.mintSkin{value: MINT_PRICE}(user1, 0, 0);
    }

    function testRevertWhen_PublicMintWrongPrice() public {
        nft.setMintingEnabled(true);

        vm.expectRevert(InvalidMintPrice.selector);
        vm.prank(user1);
        nft.mintSkin{value: 0.005 ether}(user1, 0, 0);
    }

    // --- View Functions ---

    function testGetSkinAttributes() public {
        nft.mintSkin(user1, 10, 3);

        IPlayerSkinNFT.SkinAttributes memory attrs = nft.getSkinAttributes(1);
        assertEq(attrs.weapon, 10);
        assertEq(attrs.armor, 3);
    }

    function testRevertWhen_GetSkinAttributesInvalidTokenId() public {
        vm.expectRevert(InvalidTokenId.selector);
        nft.getSkinAttributes(type(uint16).max);
    }

    function testRevertWhen_GetSkinAttributesNonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.getSkinAttributes(1);
    }

    function testTokenURI() public {
        nft.setBaseURI("https://api.example.com/skins/");
        nft.mintSkin(user1, 0, 0);

        assertEq(nft.tokenURI(1), "https://api.example.com/skins/1.json");
    }

    function testRevertWhen_TokenURIInvalidTokenId() public {
        vm.expectRevert(InvalidTokenId.selector);
        nft.tokenURI(type(uint16).max);
    }

    function testRevertWhen_TokenURINonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.tokenURI(1);
    }

    // --- Admin Functions ---

    function testSetMintingEnabled() public {
        nft.setMintingEnabled(true);
        assertTrue(nft.mintingEnabled());

        nft.setMintingEnabled(false);
        assertFalse(nft.mintingEnabled());
    }

    function testSetMintPrice() public {
        nft.setMintPrice(1 ether);
        assertEq(nft.mintPrice(), 1 ether);
    }

    function testSetBaseURI() public {
        nft.setBaseURI("ipfs://newbase/");
        assertEq(nft.baseURI(), "ipfs://newbase/");
    }

    function testRevertWhen_SetBaseURIEmpty() public {
        vm.expectRevert(InvalidBaseURI.selector);
        nft.setBaseURI("");
    }

    // --- Withdraw ---

    function testWithdraw() public {
        nft.setMintingEnabled(true);

        vm.prank(user1);
        nft.mintSkin{value: MINT_PRICE}(user1, 0, 0);

        uint256 balBefore = owner.balance;
        nft.withdraw();
        assertEq(owner.balance - balBefore, MINT_PRICE);
    }

    // --- OwnerOf ---

    function testOwnerOf() public {
        nft.mintSkin(user1, 0, 0);
        assertEq(nft.ownerOf(1), user1);
    }
}
