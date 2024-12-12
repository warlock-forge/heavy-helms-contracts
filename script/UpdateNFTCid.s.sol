// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";

contract UpdateNFTCidScript is Script {
    function setUp() public {}

    function run(address nftContractAddr, string memory newCid) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(deployerPrivateKey);

        // Get the NFT contract
        DefaultPlayerSkinNFT nft = DefaultPlayerSkinNFT(nftContractAddr);

        // Update the CID
        nft.setBaseURI(newCid);
        console2.log("NFT base URI updated to:", newCid);

        vm.stopBroadcast();
    }
}
