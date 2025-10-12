// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {DuelGame} from "../../../src/game/modes/DuelGame.sol";

contract CheckDuelResultScript is Script {
    function setUp() public {}

    function getStateString(DuelGame.ChallengeState state) internal pure returns (string memory) {
        if (state == DuelGame.ChallengeState.OPEN) return "OPEN";
        if (state == DuelGame.ChallengeState.PENDING) return "PENDING";
        if (state == DuelGame.ChallengeState.COMPLETED) return "COMPLETED";
        return "UNKNOWN";
    }

    function run(address duelGameAddr, uint256 challengeId) public {
        // Get values from .env
        uint256 deployerPrivateKey = vm.envUint("PK");
        string memory rpcUrl = vm.envString("RPC_URL");

        // Set the RPC URL
        vm.createSelectFork(rpcUrl);
        vm.startBroadcast(deployerPrivateKey);

        DuelGame duelGame = DuelGame(payable(duelGameAddr));

        // Get challenge details
        (
            uint32 challengerId,
            uint32 defenderId,
            uint256 createdBlock,
            uint256 createdTimestamp,
            uint256 vrfRequestTimestamp,,,
            DuelGame.ChallengeState state
        ) = duelGame.challenges(challengeId);

        console2.log("Challenge ID:", challengeId);
        console2.log("Challenger ID:", challengerId);
        console2.log("Defender ID:", defenderId);
        console2.log("Created Block:", createdBlock);
        console2.log("Created Timestamp:", createdTimestamp);
        console2.log("VRF Request Timestamp:", vrfRequestTimestamp);
        console2.log("State:", getStateString(state));

        if (state == DuelGame.ChallengeState.COMPLETED) {
            console2.log("Duel has been completed!");
            // You can check the DuelComplete event logs to see who won
        } else if (state == DuelGame.ChallengeState.PENDING) {
            console2.log("Duel is still pending VRF completion");
        } else {
            console2.log("Challenge is not active or has expired");
        }

        vm.stopBroadcast();
    }
}
