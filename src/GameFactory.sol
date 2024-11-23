// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameFactory is Ownable {
    UpgradeableBeacon public immutable beacon;
    address[] public games;

    event GameCreated(address indexed gameAddress, uint256 indexed gameId);

    constructor(address implementation) Ownable(msg.sender) {
        beacon = new UpgradeableBeacon(implementation, msg.sender);
    }

    function createGame() external returns (address) {
        BeaconProxy proxy = new BeaconProxy(address(beacon), "");

        address gameAddress = address(proxy);
        games.push(gameAddress);

        emit GameCreated(gameAddress, games.length - 1);

        return gameAddress;
    }

    function upgradeImplementation(
        address newImplementation
    ) external onlyOwner {
        beacon.upgradeTo(newImplementation);
    }

    function getGamesCount() external view returns (uint256) {
        return games.length;
    }

    function getGameAtIndex(uint256 index) external view returns (address) {
        require(index < games.length, "Index out of bounds");
        return games[index];
    }
}
