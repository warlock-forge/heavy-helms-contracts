// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GelatoVRFConsumerBase} from "../../lib/vrf-contracts/contracts/GelatoVRFConsumerBase.sol";
import {IPlayer} from "../../src/interfaces/IPlayer.sol";
import {Player} from "../../src/Player.sol";
import {DefaultPlayerLibrary} from "../../src/lib/DefaultPlayerLibrary.sol";
import {IPlayerSkinNFT} from "../../src/interfaces/IPlayerSkinNFT.sol";
import {DefaultPlayerSkinNFT} from "../../src/DefaultPlayerSkinNFT.sol";

abstract contract TestBase is Test {
    bool private constant CI_MODE = true;
    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;
    uint256 private constant VRF_ROUND = 335;
    address public operator;

    struct DefaultCharacters {
        uint16 greatswordOffensive;
        uint16 battleaxeOffensive;
        uint16 spearBalanced;
        uint16 swordAndShieldDefensive;
        uint16 rapierAndShieldDefensive;
        uint16 quarterstaffDefensive;
    }

    uint32 public skinIndex;
    DefaultPlayerSkinNFT public defaultSkin;

    function setUp() public virtual {
        operator = address(0x42);
        setupRandomness();
        defaultSkin = new DefaultPlayerSkinNFT();
    }

    function setupRandomness() internal {
        // Check if we're in CI environment
        try vm.envString("CI") returns (string memory) {
            console2.log("Testing in CI mode with mock randomness");
            vm.warp(1_000_000);
            vm.roll(DEFAULT_FORK_BLOCK);
            vm.prevrandao(bytes32(uint256(0x1234567890)));
        } catch {
            // Try to use RPC fork, fallback to mock if not available
            try vm.envString("RPC_URL") returns (string memory rpcUrl) {
                console2.log("Testing with forked blockchain state");
                vm.createSelectFork(rpcUrl);
            } catch {
                console2.log("No RPC_URL found, using mock randomness");
                vm.warp(1_000_000);
                vm.roll(DEFAULT_FORK_BLOCK);
                vm.prevrandao(bytes32(uint256(0x1234567890)));
            }
        }
    }

    // Helper function for VRF fulfillment with round matching
    function _fulfillVRF(uint256 requestId, uint256 randomSeed, address vrfConsumer) internal {
        bytes memory extraData = "";
        bytes memory data = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(VRF_ROUND, data);

        // Call fulfillRandomness as operator
        vm.prank(operator);
        GelatoVRFConsumerBase(vrfConsumer).fulfillRandomness(
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, operator, VRF_ROUND))), dataWithRound
        );
    }

    // Helper function to create a player with VRF
    function _createPlayerAndFulfillVRF(address owner, Player playerContract, bool useSetB)
        internal
        returns (uint256)
    {
        console2.log("Creating player for address:", owner);
        console2.log("Fee amount:", playerContract.createPlayerFeeAmount());

        // Give enough ETH to cover the fee
        vm.deal(owner, playerContract.createPlayerFeeAmount());

        // Request player creation
        vm.startPrank(owner);
        uint256 requestId = playerContract.requestCreatePlayer{value: playerContract.createPlayerFeeAmount()}(useSetB);
        vm.stopPrank();

        console2.log("Got request ID:", requestId);
        console2.log("Fulfilling VRF with request ID:", requestId);

        // Fulfill VRF request
        _fulfillVRF(
            requestId,
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, VRF_ROUND))),
            address(playerContract)
        );

        // Get the player ID from the contract
        uint256[] memory playerIds = playerContract.getPlayerIds(owner);
        console2.log("Player IDs length:", playerIds.length);
        require(playerIds.length > 0, "Player not created");

        return playerIds[playerIds.length - 1];
    }

    // Helper function to assert stat ranges
    function _assertStatRanges(IPlayer.PlayerStats memory stats, IPlayer.CalculatedStats memory calc)
        internal
        pure
        virtual
    {
        // Basic stat bounds
        assertTrue(stats.strength >= 3 && stats.strength <= 21);
        assertTrue(stats.constitution >= 3 && stats.constitution <= 21);
        assertTrue(stats.size >= 3 && stats.size <= 21);
        assertTrue(stats.agility >= 3 && stats.agility <= 21);
        assertTrue(stats.stamina >= 3 && stats.stamina <= 21);
        assertTrue(stats.luck >= 3 && stats.luck <= 21);

        // Calculated stats
        assertTrue(calc.maxHealth > 0);
        assertTrue(calc.maxEndurance > 0);
        assertTrue(calc.damageModifier > 0);
        assertTrue(calc.hitChance > 0);
        assertTrue(calc.blockChance > 0);
        assertTrue(calc.dodgeChance > 0);
        assertTrue(calc.critChance > 0);
        assertTrue(calc.initiative > 0);
        assertTrue(calc.counterChance > 0);
        assertTrue(calc.critMultiplier > 0);
        assertTrue(calc.parryChance > 0);
    }
}
