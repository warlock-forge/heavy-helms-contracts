// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {TestBase} from "../TestBase.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";
import {PlayerTicketsHandler} from "./handlers/PlayerTicketsHandler.sol";

contract PlayerTicketsInvariantTest is TestBase {
    PlayerTicketsHandler public handler;

    address[] public recipients;

    uint256 constant NUM_RECIPIENTS = 5;

    function setUp() public override {
        super.setUp();

        // Create recipient pool
        for (uint256 i = 0; i < NUM_RECIPIENTS; i++) {
            recipients.push(address(uint160(0x5001 + i)));
        }

        // Deploy handler
        handler = new PlayerTicketsHandler(playerTickets, recipients);

        // Grant handler minting permissions for all ticket types
        PlayerTickets.GamePermissions memory perms = PlayerTickets.GamePermissions({
            playerCreation: true,
            playerSlots: true,
            nameChanges: true,
            weaponSpecialization: true,
            armorSpecialization: true,
            duels: true,
            dailyResets: true,
            attributeSwaps: true
        });
        playerTickets.setGameContractPermission(address(handler), perms);

        targetContract(address(handler));
    }

    //==============================================================//
    //                         INVARIANTS                           //
    //==============================================================//

    /// @notice For each fungible ticket type, total supply across recipients must equal minted - burned
    function invariant_FungibleSupplyConsistency() public view {
        for (uint256 ticketType = 1; ticketType <= 7; ticketType++) {
            uint256 totalSupply = 0;
            for (uint256 i = 0; i < handler.getRecipientsLength(); i++) {
                address recipient = handler.getRecipient(i);
                totalSupply += playerTickets.balanceOf(recipient, ticketType);
            }

            uint256 expectedSupply = handler.getGhostMinted(ticketType) - handler.getGhostBurned(ticketType);
            assertEq(totalSupply, expectedSupply, "Fungible supply mismatch");
        }
    }

    /// @notice nextNameChangeTokenId tracks name NFTs minted
    function invariant_NameNFTIdMonotonic() public view {
        uint256 expectedNextId = 100 + handler.ghost_nameNFTsMinted();
        assertEq(
            playerTickets.nextNameChangeTokenId(), expectedNextId, "nextNameChangeTokenId doesn't match minted count"
        );
    }

    /// @notice Name NFT balances should all be 0 or 1 (non-fungible)
    function invariant_NameNFTsAreNonFungible() public view {
        uint256 nextId = playerTickets.nextNameChangeTokenId();
        for (uint256 tokenId = 100; tokenId < nextId; tokenId++) {
            uint256 totalHolders = 0;
            for (uint256 i = 0; i < handler.getRecipientsLength(); i++) {
                address recipient = handler.getRecipient(i);
                uint256 bal = playerTickets.balanceOf(recipient, tokenId);
                assertLe(bal, 1, "Name NFT balance > 1");
                totalHolders += bal;
            }
            assertLe(totalHolders, 1, "Name NFT held by multiple recipients");
        }
    }

    /// @notice Call summary for debugging
    function invariant_callSummary() public view {
        handler.calls_mintFungible();
        handler.calls_burn();
        handler.calls_transfer();
        handler.calls_mintNameNFT();
    }
}
