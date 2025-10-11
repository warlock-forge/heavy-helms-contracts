// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

//==============================================================//
//                          IMPORTS                             //
//==============================================================//
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
/// @notice Thrown when caller is not authorized
error NotAuthorized();

//==============================================================//
//                         HEAVY HELMS                          //
//                    TEST TICKET MINTER                        //
//==============================================================//
/// @title Test Player Ticket Minter
/// @notice Test-only contract for minting tickets during testing
/// @dev This contract should NEVER be deployed to production
contract TestPlayerTicketMinter {
    //==============================================================//
    //                      STATE VARIABLES                         //
    //==============================================================//
    /// @notice Reference to the PlayerTickets contract
    PlayerTickets public immutable playerTickets;

    /// @notice Address authorized to mint tickets (typically the test contract)
    address public immutable authorized;

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor(address _playerTickets, address _authorized) {
        playerTickets = PlayerTickets(_playerTickets);
        authorized = _authorized;
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//

    /// @notice Mints any fungible ticket type for testing
    /// @param to Address to mint tickets to
    /// @param ticketType The type of ticket to mint (1-7)
    /// @param amount Number of tickets to mint
    function mintFungibleTicket(address to, uint256 ticketType, uint256 amount) external {
        if (msg.sender != authorized) revert NotAuthorized();
        playerTickets.mintFungibleTicket(to, ticketType, amount);
    }

    /// @notice Mints a name change NFT for testing
    /// @param to Address to mint the NFT to
    /// @param seed Seed for randomness
    /// @return tokenId The ID of the minted NFT
    function mintNameChangeNFT(address to, uint256 seed) external returns (uint256 tokenId) {
        if (msg.sender != authorized) revert NotAuthorized();
        return playerTickets.mintNameChangeNFT(to, seed);
    }

    /// @notice Batch mints multiple fungible tickets for testing
    /// @param to Address to mint tickets to
    /// @param ticketTypes Array of ticket types (must be 1-7)
    /// @param amounts Array of amounts to mint for each type
    function batchMintFungibleTickets(address to, uint256[] calldata ticketTypes, uint256[] calldata amounts) external {
        if (msg.sender != authorized) revert NotAuthorized();
        require(ticketTypes.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ticketTypes.length; i++) {
            playerTickets.mintFungibleTicket(to, ticketTypes[i], amounts[i]);
        }
    }
}
