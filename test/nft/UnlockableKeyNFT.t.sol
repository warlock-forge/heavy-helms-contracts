// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    UnlockableKeyNFT,
    MintingDisabled,
    InvalidMintPrice,
    PublicMintExhausted,
    MaxSupplyReached,
    InvalidMintAmount,
    TokenDoesNotExist,
    InvalidBaseURI
} from "../../src/nft/skins/UnlockableKeyNFT.sol";

contract UnlockableKeyNFTTest is Test {
    receive() external payable {}

    UnlockableKeyNFT public nft;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public royaltyReceiver = address(0x99);

    uint16 public constant MAX_SUPPLY = 100;
    uint16 public constant PUBLIC_SUPPLY = 80;
    uint256 public constant MINT_PRICE = 0.05 ether;
    uint96 public constant ROYALTY_BPS = 500; // 5%

    function setUp() public {
        nft = new UnlockableKeyNFT(
            "Test Key", "TKEY", MAX_SUPPLY, PUBLIC_SUPPLY, MINT_PRICE, royaltyReceiver, ROYALTY_BPS
        );
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // --- Constructor ---

    function testConstructorState() public view {
        assertEq(nft.name(), "Test Key");
        assertEq(nft.symbol(), "TKEY");
        assertEq(nft.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(nft.PUBLIC_SUPPLY(), PUBLIC_SUPPLY);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(nft.currentTokenId(), 1);
        assertEq(nft.publicMintRemaining(), PUBLIC_SUPPLY);
        assertFalse(nft.mintingEnabled());
    }

    // --- Public Mint ---

    function testMint() public {
        nft.setMintingEnabled(true);

        vm.prank(user1);
        uint16 tokenId = nft.mint{value: MINT_PRICE}();

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.currentTokenId(), 2);
        assertEq(nft.publicMinted(), 1);
        assertEq(nft.publicMintRemaining(), PUBLIC_SUPPLY - 1);
    }

    function testRevertWhen_MintDisabled() public {
        vm.expectRevert(MintingDisabled.selector);
        vm.prank(user1);
        nft.mint{value: MINT_PRICE}();
    }

    function testRevertWhen_InvalidMintPrice() public {
        nft.setMintingEnabled(true);

        vm.expectRevert(InvalidMintPrice.selector);
        vm.prank(user1);
        nft.mint{value: 0.01 ether}();
    }

    function testRevertWhen_PublicMintExhausted() public {
        // Use a small supply NFT for this test
        UnlockableKeyNFT small = new UnlockableKeyNFT("Small", "SM", 10, 2, MINT_PRICE, royaltyReceiver, ROYALTY_BPS);
        small.setMintingEnabled(true);

        vm.startPrank(user1);
        small.mint{value: MINT_PRICE}();
        small.mint{value: MINT_PRICE}();

        vm.expectRevert(PublicMintExhausted.selector);
        small.mint{value: MINT_PRICE}();
        vm.stopPrank();
    }

    function testRevertWhen_MaxSupplyReachedOnMint() public {
        // Max supply 5, public supply 3 — owner fills remaining slots so max supply is hit
        UnlockableKeyNFT tiny = new UnlockableKeyNFT("Tiny", "TN", 5, 3, MINT_PRICE, royaltyReceiver, ROYALTY_BPS);
        tiny.setMintingEnabled(true);
        // Owner mints 3 (IDs 1-3), leaving supply for 2 more, but public has 3 slots
        tiny.ownerMint(user2, 3);

        vm.startPrank(user1);
        tiny.mint{value: MINT_PRICE}();
        tiny.mint{value: MINT_PRICE}();

        // Now _currentTokenId is 6 which is > MAX_SUPPLY(5)
        vm.expectRevert(MaxSupplyReached.selector);
        tiny.mint{value: MINT_PRICE}();
        vm.stopPrank();
    }

    // --- Owner Mint ---

    function testOwnerMint() public {
        nft.ownerMint(user1, 5);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(5), user1);
        assertEq(nft.currentTokenId(), 6);
        // ownerMint does NOT increment publicMinted
        assertEq(nft.publicMinted(), 0);
    }

    function testRevertWhen_OwnerMintZeroAmount() public {
        vm.expectRevert(InvalidMintAmount.selector);
        nft.ownerMint(user1, 0);
    }

    function testRevertWhen_OwnerMintExceedsMaxSupply() public {
        vm.expectRevert(MaxSupplyReached.selector);
        nft.ownerMint(user1, MAX_SUPPLY + 1);
    }

    function testRevertWhen_OwnerMintNotOwner() public {
        vm.expectRevert("Only callable by owner");
        vm.prank(user1);
        nft.ownerMint(user1, 1);
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
        nft.setBaseURI("ipfs://newuri/");
        assertEq(nft.baseURI(), "ipfs://newuri/");
    }

    function testRevertWhen_SetBaseURIEmpty() public {
        vm.expectRevert(InvalidBaseURI.selector);
        nft.setBaseURI("");
    }

    // --- Token URI ---

    function testTokenURI() public {
        nft.setBaseURI("ipfs://test/");
        nft.ownerMint(user1, 1);
        assertEq(nft.tokenURI(1), "ipfs://test/");
    }

    function testRevertWhen_TokenURINonExistent() public {
        vm.expectRevert(TokenDoesNotExist.selector);
        nft.tokenURI(999);
    }

    // --- Royalties ---

    function testRoyaltyInfo() public {
        nft.ownerMint(user1, 1);
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10000);
        assertEq(receiver, royaltyReceiver);
        assertEq(amount, 500); // 5% of 10000
    }

    function testSetDefaultRoyalty() public {
        nft.setDefaultRoyalty(user2, 1000);
        nft.ownerMint(user1, 1);
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10000);
        assertEq(receiver, user2);
        assertEq(amount, 1000); // 10%
    }

    // --- SupportsInterface ---

    function testSupportsInterface() public view {
        // ERC721
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC2981
        assertTrue(nft.supportsInterface(0x2a55205a));
        // ERC165
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }

    // --- Withdraw ---

    function testWithdraw() public {
        nft.setMintingEnabled(true);

        vm.prank(user1);
        nft.mint{value: MINT_PRICE}();

        uint256 balBefore = owner.balance;
        nft.withdraw();
        assertEq(owner.balance - balBefore, MINT_PRICE);
    }
}
