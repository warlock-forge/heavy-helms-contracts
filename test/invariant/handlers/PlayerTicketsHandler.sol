// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {PlayerTickets} from "../../../src/nft/PlayerTickets.sol";

/// @notice Handler for PlayerTickets invariant testing.
/// @dev Exercises minting, burning, and transfer of fungible tickets and name NFTs.
contract PlayerTicketsHandler is Test {
    PlayerTickets public tickets;

    // Pool of recipient addresses
    address[] public recipients;

    // Ghost variables
    mapping(uint256 => uint256) public ghost_totalMinted; // tokenId => total minted
    mapping(uint256 => uint256) public ghost_totalBurned; // tokenId => total burned
    uint256 public ghost_nameNFTsMinted;

    // Call counters
    uint256 public calls_mintFungible;
    uint256 public calls_burn;
    uint256 public calls_transfer;
    uint256 public calls_mintNameNFT;

    constructor(PlayerTickets _tickets, address[] memory _recipients) {
        tickets = _tickets;

        for (uint256 i = 0; i < _recipients.length; i++) {
            recipients.push(_recipients[i]);
        }
    }

    // --- Handler Actions ---

    /// @notice Mint a random fungible ticket to a random recipient
    function mintFungible(uint256 recipientSeed, uint256 ticketType, uint256 amount) external {
        if (recipients.length == 0) return;

        address to = recipients[recipientSeed % recipients.length];
        ticketType = bound(ticketType, 1, 7);
        amount = bound(amount, 1, 10);

        try tickets.mintFungibleTicket(to, ticketType, amount) {
            ghost_totalMinted[ticketType] += amount;
            calls_mintFungible++;
        } catch {}
    }

    /// @notice Burn tokens from a random recipient
    function burn(uint256 recipientSeed, uint256 ticketType, uint256 amount) external {
        if (recipients.length == 0) return;

        address from = recipients[recipientSeed % recipients.length];
        ticketType = bound(ticketType, 1, 7);
        amount = bound(amount, 1, 5);

        uint256 balance = tickets.balanceOf(from, ticketType);
        if (balance == 0) return;
        if (amount > balance) amount = balance;

        // Approve the handler to burn
        vm.prank(from);
        tickets.setApprovalForAll(address(this), true);

        try tickets.burnFrom(from, ticketType, amount) {
            ghost_totalBurned[ticketType] += amount;
            calls_burn++;
        } catch {}
    }

    /// @notice Transfer fungible tickets between recipients (includes soulbound attempts)
    function transfer(uint256 fromSeed, uint256 toSeed, uint256 ticketType, uint256 amount) external {
        if (recipients.length < 2) return;

        address from = recipients[fromSeed % recipients.length];
        address to = recipients[toSeed % recipients.length];
        if (from == to) {
            to = recipients[(toSeed + 1) % recipients.length];
            if (from == to) return;
        }

        // Allow ALL ticket types 1-7 (including soulbound) to exercise the transfer block
        ticketType = bound(ticketType, 1, 7);
        amount = bound(amount, 1, 5);

        uint256 balance = tickets.balanceOf(from, ticketType);
        if (balance == 0) return;
        if (amount > balance) amount = balance;

        vm.prank(from);
        try tickets.safeTransferFrom(from, to, ticketType, amount, "") {
            calls_transfer++;
            // If soulbound token (7) transfer succeeded, that's a bug!
            // The invariant will catch the supply inconsistency.
        } catch {}
    }

    /// @notice Mint a name change NFT
    function mintNameNFT(uint256 recipientSeed, uint256 seed) external {
        if (recipients.length == 0) return;

        address to = recipients[recipientSeed % recipients.length];

        try tickets.mintNameChangeNFT(to, seed) {
            ghost_nameNFTsMinted++;
            calls_mintNameNFT++;
        } catch {}
    }

    // --- View helpers ---

    function getRecipientsLength() external view returns (uint256) {
        return recipients.length;
    }

    function getRecipient(uint256 index) external view returns (address) {
        return recipients[index];
    }

    function getGhostMinted(uint256 ticketType) external view returns (uint256) {
        return ghost_totalMinted[ticketType];
    }

    function getGhostBurned(uint256 ticketType) external view returns (uint256) {
        return ghost_totalBurned[ticketType];
    }
}
