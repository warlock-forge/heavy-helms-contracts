// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {
    PlayerSkinRegistry,
    InsufficientRegistrationFee,
    NoTokensToCollect,
    SkinRegistryDoesNotExist,
    RequiredNFTNotOwned,
    SkinNotOwned,
    ZeroAddressNotAllowed,
    InvalidSkinType,
    EquipmentRequirementsNotMet
} from "../../src/fighters/registries/skins/PlayerSkinRegistry.sol";
import {IPlayerSkinRegistry} from "../../src/interfaces/fighters/registries/skins/IPlayerSkinRegistry.sol";
import {PlayerSkinNFT} from "../../src/nft/skins/PlayerSkinNFT.sol";
import {DefaultPlayerSkinNFT} from "../../src/nft/skins/DefaultPlayerSkinNFT.sol";
import {MonsterSkinNFT} from "../../src/nft/skins/MonsterSkinNFT.sol";
import {UnlockableKeyNFT} from "../../src/nft/skins/UnlockableKeyNFT.sol";
import {EquipmentRequirements} from "../../src/game/engine/EquipmentRequirements.sol";
import {IEquipmentRequirements} from "../../src/interfaces/game/engine/IEquipmentRequirements.sol";
import {Fighter} from "../../src/fighters/Fighter.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/nft/skins/IPlayerSkinNFT.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Mock";
    }

    function symbol() public pure override returns (string memory) {
        return "MCK";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PlayerSkinRegistryTest is Test {
    PlayerSkinRegistry public registry;
    DefaultPlayerSkinNFT public defaultSkin;
    MonsterSkinNFT public monsterSkin;
    PlayerSkinNFT public playerSkin;
    UnlockableKeyNFT public keyNFT;
    EquipmentRequirements public equipReqs;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        vm.deal(address(this), 100 ether);
        vm.deal(user1, 10 ether);

        registry = new PlayerSkinRegistry();
        defaultSkin = new DefaultPlayerSkinNFT();
        monsterSkin = new MonsterSkinNFT();
        equipReqs = new EquipmentRequirements();

        // Deploy a PlayerSkinNFT for testing
        playerSkin = new PlayerSkinNFT("Test Player Skins", "TPS", 0.01 ether);

        // Deploy an UnlockableKeyNFT for testing requiredNFT
        keyNFT = new UnlockableKeyNFT("Test Key", "TK", 100, 50, 0.01 ether, address(this), 500);

        // Mint a default player skin
        defaultSkin.mintDefaultPlayerSkin(1, 0, "QmTestCID1", 1);

        // Mint a player skin (to=this, weapon=1, armor=0)
        playerSkin.mintSkin(address(this), 1, 0);
    }

    // --- registerSkin ---

    function testRegisterSkinAsOwner() public {
        uint32 id = registry.registerSkin(address(playerSkin));
        assertEq(id, 0);

        IPlayerSkinRegistry.SkinCollectionInfo memory info = registry.getSkin(0);
        assertEq(info.contractAddress, address(playerSkin));
        assertFalse(info.isVerified);
        assertEq(uint8(info.skinType), uint8(IPlayerSkinRegistry.SkinType.Player));
    }

    function testRegisterSkinWithFee() public {
        uint256 fee = registry.registrationFee();
        vm.prank(user1);
        uint32 id = registry.registerSkin{value: fee}(address(playerSkin));
        assertEq(id, 0);
    }

    function testRevertWhen_RegisterSkinInsufficientFee() public {
        vm.expectRevert(InsufficientRegistrationFee.selector);
        vm.prank(user1);
        registry.registerSkin{value: 0.001 ether}(address(playerSkin));
    }

    function testRevertWhen_RegisterSkinZeroAddress() public {
        vm.expectRevert(ZeroAddressNotAllowed.selector);
        registry.registerSkin(address(0));
    }

    // --- getSkin ---

    function testRevertWhen_GetSkinDoesNotExist() public {
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        registry.getSkin(0);
    }

    // --- validateSkinOwnership ---

    function testValidateSkinOwnershipDefaultPlayer() public {
        // Register and set as DefaultPlayer type
        uint32 id = registry.registerSkin(address(defaultSkin));
        registry.setSkinType(id, IPlayerSkinRegistry.SkinType.DefaultPlayer);

        // Anyone can equip DefaultPlayer skins
        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        registry.validateSkinOwnership(skin, user1); // Should not revert
    }

    function testRevertWhen_ValidateSkinOwnershipMonsterType() public {
        uint32 id = registry.registerSkin(address(monsterSkin));
        registry.setSkinType(id, IPlayerSkinRegistry.SkinType.Monster);

        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        vm.expectRevert(InvalidSkinType.selector);
        registry.validateSkinOwnership(skin, user1);
    }

    function testValidateSkinOwnershipWithRequiredNFT() public {
        uint32 id = registry.registerSkin(address(playerSkin));
        // Mint key NFT to user1
        keyNFT.ownerMint(user1, 1);
        registry.setRequiredNFT(id, address(keyNFT));

        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        registry.validateSkinOwnership(skin, user1); // Should not revert
    }

    function testRevertWhen_ValidateSkinOwnershipMissingRequiredNFT() public {
        uint32 id = registry.registerSkin(address(playerSkin));
        registry.setRequiredNFT(id, address(keyNFT));

        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        vm.expectRevert(abi.encodeWithSelector(RequiredNFTNotOwned.selector, address(keyNFT)));
        registry.validateSkinOwnership(skin, user1);
    }

    function testValidateSkinOwnershipRegularCollection() public {
        uint32 id = registry.registerSkin(address(playerSkin));

        // Owner of tokenId 1 is address(this) since we minted in setUp
        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        registry.validateSkinOwnership(skin, address(this)); // Should not revert
    }

    function testRevertWhen_ValidateSkinOwnershipNotOwned() public {
        uint32 id = registry.registerSkin(address(playerSkin));

        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        vm.expectRevert(abi.encodeWithSelector(SkinNotOwned.selector, address(playerSkin), uint16(1)));
        registry.validateSkinOwnership(skin, user1);
    }

    function testRevertWhen_ValidateSkinOwnershipInvalidIndex() public {
        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: 999, skinTokenId: 1});
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        registry.validateSkinOwnership(skin, user1);
    }

    // --- getVerifiedSkins ---

    function testGetVerifiedSkins() public {
        registry.registerSkin(address(defaultSkin));
        registry.registerSkin(address(playerSkin));
        registry.registerSkin(address(monsterSkin));

        // Verify only the first two
        registry.setSkinVerification(0, true);
        registry.setSkinVerification(1, true);

        IPlayerSkinRegistry.SkinCollectionInfo[] memory verified = registry.getVerifiedSkins();
        assertEq(verified.length, 2);
        assertEq(verified[0].contractAddress, address(defaultSkin));
        assertEq(verified[1].contractAddress, address(playerSkin));
    }

    function testGetVerifiedSkinsEmpty() public view {
        IPlayerSkinRegistry.SkinCollectionInfo[] memory verified = registry.getVerifiedSkins();
        assertEq(verified.length, 0);
    }

    // --- collect ---

    function testCollectETH() public {
        // Send ETH via registration fee
        vm.prank(user1);
        registry.registerSkin{value: registry.registrationFee()}(address(playerSkin));

        uint256 balBefore = address(this).balance;
        registry.collect(address(0));
        assertTrue(address(this).balance > balBefore);
    }

    function testRevertWhen_CollectETHZeroBalance() public {
        vm.expectRevert(NoTokensToCollect.selector);
        registry.collect(address(0));
    }

    function testCollectERC20() public {
        MockERC20 token = new MockERC20();
        token.mint(address(registry), 100);

        registry.collect(address(token));
        assertEq(token.balanceOf(address(this)), 100);
    }

    function testRevertWhen_CollectERC20ZeroBalance() public {
        MockERC20 token = new MockERC20();
        vm.expectRevert(NoTokensToCollect.selector);
        registry.collect(address(token));
    }

    // --- Admin Functions ---

    function testSetSkinVerification() public {
        registry.registerSkin(address(playerSkin));
        registry.setSkinVerification(0, true);

        IPlayerSkinRegistry.SkinCollectionInfo memory info = registry.getSkin(0);
        assertTrue(info.isVerified);

        registry.setSkinVerification(0, false);
        info = registry.getSkin(0);
        assertFalse(info.isVerified);
    }

    function testRevertWhen_SetSkinVerificationInvalidId() public {
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        registry.setSkinVerification(999, true);
    }

    function testSetRequiredNFT() public {
        registry.registerSkin(address(playerSkin));
        registry.setRequiredNFT(0, address(keyNFT));

        IPlayerSkinRegistry.SkinCollectionInfo memory info = registry.getSkin(0);
        assertEq(info.requiredNFTAddress, address(keyNFT));

        // Can also clear the requirement
        registry.setRequiredNFT(0, address(0));
        info = registry.getSkin(0);
        assertEq(info.requiredNFTAddress, address(0));
    }

    function testRevertWhen_SetRequiredNFTInvalidId() public {
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        registry.setRequiredNFT(999, address(keyNFT));
    }

    function testSetRegistrationFee() public {
        registry.setRegistrationFee(0.01 ether);
        assertEq(registry.registrationFee(), 0.01 ether);
    }

    function testSetSkinType() public {
        registry.registerSkin(address(defaultSkin));
        registry.setSkinType(0, IPlayerSkinRegistry.SkinType.DefaultPlayer);

        IPlayerSkinRegistry.SkinCollectionInfo memory info = registry.getSkin(0);
        assertEq(uint8(info.skinType), uint8(IPlayerSkinRegistry.SkinType.DefaultPlayer));
    }

    function testRevertWhen_SetSkinTypeInvalidId() public {
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        registry.setSkinType(999, IPlayerSkinRegistry.SkinType.Player);
    }

    // --- validateSkinRequirements ---

    function testValidateSkinRequirementsMonsterSkip() public {
        // Monster type skins skip requirement checks
        uint32 id = registry.registerSkin(address(monsterSkin));
        registry.setSkinType(id, IPlayerSkinRegistry.SkinType.Monster);

        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        Fighter.Attributes memory attrs =
            Fighter.Attributes({strength: 3, constitution: 3, size: 3, agility: 3, stamina: 3, luck: 3});

        // Should not revert even with low stats
        registry.validateSkinRequirements(skin, attrs, IEquipmentRequirements(address(equipReqs)));
    }

    function testValidateSkinRequirementsPass() public {
        // Register a skin with weapon/armor that have requirements
        uint32 id = registry.registerSkin(address(defaultSkin));
        registry.setSkinType(id, IPlayerSkinRegistry.SkinType.DefaultPlayer);

        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: id, skinTokenId: 1});
        // High stats should pass any requirement
        Fighter.Attributes memory attrs =
            Fighter.Attributes({strength: 21, constitution: 21, size: 21, agility: 21, stamina: 21, luck: 21});

        registry.validateSkinRequirements(skin, attrs, IEquipmentRequirements(address(equipReqs)));
    }

    function testRevertWhen_ValidateSkinRequirementsInvalidIndex() public {
        Fighter.SkinInfo memory skin = Fighter.SkinInfo({skinIndex: 999, skinTokenId: 1});
        Fighter.Attributes memory attrs;
        vm.expectRevert(SkinRegistryDoesNotExist.selector);
        registry.validateSkinRequirements(skin, attrs, IEquipmentRequirements(address(equipReqs)));
    }

    receive() external payable {}
}
