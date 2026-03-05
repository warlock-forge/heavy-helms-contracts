// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Player} from "../../src/fighters/Player.sol";
import {PlayerTickets} from "../../src/nft/PlayerTickets.sol";

contract MaliciousERC1155Receiver {
    Player public target;
    PlayerTickets public tickets;
    bool public attacking;

    constructor(Player _target, PlayerTickets _tickets) {
        target = _target;
        tickets = _tickets;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (attacking) {
            target.purchasePlayerSlotsWithTickets();
        }
        return this.onERC1155Received.selector;
    }

    function attack() external {
        attacking = true;
        attacking = false;
    }
}
