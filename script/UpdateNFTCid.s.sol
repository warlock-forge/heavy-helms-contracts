// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DefaultPlayerSkinNFT} from "../src/DefaultPlayerSkinNFT.sol";

contract UpdateNFTCidScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        // Address of your deployed DefaultPlayerSkinNFT contract
        address defaultSkinAddress = 0x3A77a77CA3c6A2B25F847b3c1c404d680D46bCd2; // Replace with your contract address
        DefaultPlayerSkinNFT defaultSkin = DefaultPlayerSkinNFT(defaultSkinAddress);

        // Update CID for specific token ID
        uint256 tokenId = 1; // Replace with your token ID
        string memory newCID = "QmTZzCarXPyWK483Eve4NsQLwiJbCuWhAbnPx2sVRyfKqC"; // Replace with your new IPFS CID

        defaultSkin.setCID(tokenId, newCID);

        console2.log("Updated CID for token", tokenId);
        console2.log("New URI:", defaultSkin.tokenURI(tokenId));

        vm.stopBroadcast();
    }
}
