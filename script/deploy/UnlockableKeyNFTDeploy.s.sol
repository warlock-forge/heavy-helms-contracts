// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UnlockableKeyNFT} from "../../src/nft/skins/UnlockableKeyNFT.sol";

contract UnlockableKeyNFTDeployScript is Script {
    // --- Configuration ---
    string constant NAME = "Heavy Helms Monster001";
    string constant SYMBOL = "HHM001";
    uint16 constant MAX_SUPPLY = 250;
    uint16 constant PUBLIC_SUPPLY = 200;
    uint16 constant RESERVE_AMOUNT = 50;
    uint256 constant MINT_PRICE = 0.05 ether;
    uint96 constant ROYALTY_BPS = 500; // 5%
    string constant BASE_URI = "ipfs://bafkreifnat57awyij2zxmrrn77ro4v3fryzajaqvf5yw6g6odvzgny2ove";

    function run(address deployer) public {
        string memory rpcUrl = vm.envString("RPC_URL");

        vm.createSelectFork(rpcUrl);
        vm.startBroadcast();

        console2.log("\n=== Deploying UnlockableKeyNFT ===");
        console2.log("Deployer:", deployer);

        // Deploy the key NFT
        UnlockableKeyNFT keyNFT = new UnlockableKeyNFT(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            PUBLIC_SUPPLY,
            MINT_PRICE,
            deployer, // royalty receiver
            ROYALTY_BPS
        );

        console2.log("UnlockableKeyNFT deployed:", address(keyNFT));

        // Set base URI
        keyNFT.setBaseURI(BASE_URI);
        console2.log("Base URI set");

        // Pre-mint reserves to deployer
        keyNFT.ownerMint(deployer, RESERVE_AMOUNT);
        console2.log("Reserved", RESERVE_AMOUNT, "tokens to deployer");

        // Enable public minting
        keyNFT.setMintingEnabled(true);
        console2.log("Public minting enabled");

        console2.log("\n=== Deployment Summary ===");
        console2.log("Contract:", address(keyNFT));
        console2.log("Max Supply:", MAX_SUPPLY);
        console2.log("Public Supply:", PUBLIC_SUPPLY);
        console2.log("Reserved:", RESERVE_AMOUNT);
        console2.log("Mint Price:", MINT_PRICE);
        console2.log("Royalty:", ROYALTY_BPS, "bps");

        vm.stopBroadcast();
    }
}
