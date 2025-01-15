// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PlayerNameRegistry.sol";

contract PlayerNameRegistryGasTest is Test {
    uint256 constant BLOCK_GAS_LIMIT = 30_000_000;

    function setUp() public {
        vm.chainId(360);
    }

    function testDeploymentGas() public {
        uint256 startGas = gasleft();
        new PlayerNameRegistry();
        uint256 gasUsed = startGas - gasleft();

        uint256 percentUsed = (gasUsed * 100) / BLOCK_GAS_LIMIT;

        console2.log("Gas used for deployment:", gasUsed);
        console2.log("Percentage of block limit:", percentUsed, "%");

        // Assert it's under typical OP block limit of 30M
        assertLt(gasUsed, BLOCK_GAS_LIMIT, "Deployment exceeds typical OP block gas limit");
    }
}
