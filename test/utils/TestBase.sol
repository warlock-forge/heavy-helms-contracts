// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

abstract contract TestBase is Test {
    bool private constant CI_MODE = true;
    uint256 private constant DEFAULT_FORK_BLOCK = 19_000_000;

    function setUp() public virtual {
        setupRandomness();
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
}
