// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MonsterSkinNFT} from "../../src/nft/skins/MonsterSkinNFT.sol";
import {
    InvalidCID,
    MaxSupplyReached,
    TokenDoesNotExist,
    TokenIdAlreadyExists,
    InvalidTokenId
} from "../../src/nft/base/GameOwnedNFT.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/nft/skins/IPlayerSkinNFT.sol";

contract GameOwnedNFTTest is Test {
    receive() external payable {}

    MonsterSkinNFT public nft;

    address public owner = address(this);
    address public user1 = address(0x1);

    function setUp() public {
        nft = new MonsterSkinNFT();
    }

    // --- Constructor ---

    function testConstructorState() public view {
        assertEq(nft.name(), "Heavy Helms Monster Skins");
        assertEq(nft.symbol(), "HHMON");
        assertEq(nft.MAX_SUPPLY(), 8000);
        assertEq(nft.CURRENT_TOKEN_ID(), 1);
    }

    // --- Mint ---

    function testMintMonsterSkin() public {
        uint16 tokenId = nft.mintMonsterSkin(3, 2, "QmTestCID123", 1);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(1), address(nft));
        assertEq(nft.CURRENT_TOKEN_ID(), 2);

        IPlayerSkinNFT.SkinAttributes memory attrs = nft.getSkinAttributes(1);
        assertEq(attrs.weapon, 3);
        assertEq(attrs.armor, 2);
    }

    function testMintMultipleSkins() public {
        nft.mintMonsterSkin(0, 0, "QmCID1", 1);
        nft.mintMonsterSkin(5, 1, "QmCID2", 2);
        nft.mintMonsterSkin(10, 3, "QmCID3", 5);

        assertEq(nft.CURRENT_TOKEN_ID(), 6);
        assertEq(nft.ownerOf(1), address(nft));
        assertEq(nft.ownerOf(5), address(nft));
    }

    function testRevertWhen_MaxSupplyReached() public {
        vm.expectRevert(MaxSupplyReached.selector);
        nft.mintMonsterSkin(0, 0, "QmCID", 8000);
    }

    function testRevertWhen_InvalidCID() public {
        vm.expectRevert(InvalidCID.selector);
        nft.mintMonsterSkin(0, 0, "", 1);
    }

    function testRevertWhen_TokenIdAlreadyExists() public {
        nft.mintMonsterSkin(0, 0, "QmCID1", 1);

        vm.expectRevert(abi.encodeWithSelector(TokenIdAlreadyExists.selector, 1));
        nft.mintMonsterSkin(0, 0, "QmCID2", 1);
    }

    function testRevertWhen_MintNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.prank(user1);
        nft.mintMonsterSkin(0, 0, "QmCID", 1);
    }

    // --- View Functions ---

    function testTokenURI() public {
        nft.mintMonsterSkin(0, 0, "QmTestHash", 1);
        assertEq(nft.tokenURI(1), "ipfs://QmTestHash");
    }

    function testRevertWhen_TokenURINonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.tokenURI(999);
    }

    function testRevertWhen_GetSkinAttributesNonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.getSkinAttributes(999);
    }

    // --- Admin: setCID ---

    function testSetCID() public {
        nft.mintMonsterSkin(0, 0, "QmOldCID", 1);
        nft.setCID(1, "QmNewCID");
        assertEq(nft.tokenURI(1), "ipfs://QmNewCID");
    }

    function testRevertWhen_SetCIDEmpty() public {
        nft.mintMonsterSkin(0, 0, "QmCID", 1);

        vm.expectRevert(InvalidCID.selector);
        nft.setCID(1, "");
    }

    function testRevertWhen_SetCIDNonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.setCID(999, "QmNewCID");
    }

    // --- Admin: updateSkinAttributes ---

    function testUpdateSkinAttributes() public {
        nft.mintMonsterSkin(0, 0, "QmCID", 1);
        nft.updateSkinAttributes(1, 5, 3);

        IPlayerSkinNFT.SkinAttributes memory attrs = nft.getSkinAttributes(1);
        assertEq(attrs.weapon, 5);
        assertEq(attrs.armor, 3);
    }

    function testRevertWhen_UpdateSkinAttributesInvalidTokenId() public {
        vm.expectRevert(InvalidTokenId.selector);
        nft.updateSkinAttributes(type(uint16).max, 0, 0);
    }

    function testRevertWhen_UpdateSkinAttributesNonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.updateSkinAttributes(999, 0, 0);
    }

    // --- Withdraw ---

    function testWithdraw() public {
        vm.deal(address(nft), 1 ether);
        uint256 balBefore = owner.balance;
        nft.withdraw();
        assertEq(owner.balance - balBefore, 1 ether);
    }
}
