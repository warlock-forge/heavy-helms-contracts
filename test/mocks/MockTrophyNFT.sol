// SPDX-License-Identifier: GPL-3.0-or-later
// ██╗    ██╗ █████╗ ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
// ██║    ██║██╔══██╗██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
// ██║ █╗ ██║███████║██████╔╝██║     ██║   ██║██║     █████╔╝     █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
// ██║███╗██║██╔══██║██╔══██╗██║     ██║   ██║██║     ██╔═██╗     ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
// ╚███╔███╔╝██║  ██║██║  ██║███████╗╚██████╔╝╚██████╗██║  ██╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
//  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
pragma solidity ^0.8.13;

import {ERC721} from "solady/tokens/ERC721.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {ITrophyNFT} from "../../src/interfaces/nft/ITrophyNFT.sol";

//==============================================================//
//                       CUSTOM ERRORS                          //
//==============================================================//
error NotAuthorizedMinter();
error TokenDoesNotExist();

//==============================================================//
//                         MOCK TROPHY NFT                      //
//==============================================================//
/// @title Mock Trophy NFT for Testing
/// @notice Simple implementation of ITrophyNFT for testing integration
contract MockTrophyNFT is ITrophyNFT, ERC721, ConfirmedOwner {
    //==============================================================//
    //                      STATE VARIABLES                         //
    //==============================================================//
    /// @notice Address authorized to mint trophies (MonsterBattleGame)
    address public authorizedMinter;
    /// @notice Current token ID counter
    uint256 private _currentTokenId = 1;
    /// @notice Monster type this trophy represents
    string public monsterType;

    /// @notice Maps token IDs to their trophy metadata
    mapping(uint256 => TrophyMetadata) private _trophyData;

    //==============================================================//
    //                        MODIFIERS                             //
    //==============================================================//
    modifier onlyAuthorizedMinter() {
        if (msg.sender != authorizedMinter) revert NotAuthorizedMinter();
        _;
    }

    //==============================================================//
    //                       CONSTRUCTOR                            //
    //==============================================================//
    constructor(string memory _monsterType, address _authorizedMinter) ConfirmedOwner(msg.sender) {
        monsterType = _monsterType;
        authorizedMinter = _authorizedMinter;
    }

    //==============================================================//
    //                       VIEW FUNCTIONS                         //
    //==============================================================//
    function name() public view override returns (string memory) {
        return string(abi.encodePacked(monsterType, " Trophy"));
    }

    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked(monsterType, "TROPHY"));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked("https://api.heavyhelms.com/trophy/", monsterType, "/", toString(tokenId)));
    }

    function getTrophyMetadata(uint256 tokenId) external view returns (TrophyMetadata memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _trophyData[tokenId];
    }

    function totalSupply() external view returns (uint256) {
        return _currentTokenId - 1;
    }

    //==============================================================//
    //                    EXTERNAL FUNCTIONS                        //
    //==============================================================//
    function mintTrophy(
        address to,
        uint32 monsterId,
        string calldata monsterName,
        uint8 difficulty,
        uint32 killerPlayerId,
        string calldata killerPlayerName
    ) external onlyAuthorizedMinter returns (uint256 tokenId) {
        tokenId = _currentTokenId++;
        _mint(to, tokenId);

        _trophyData[tokenId] = TrophyMetadata({
            monsterId: monsterId,
            monsterName: monsterName,
            difficulty: difficulty,
            killBlock: block.number,
            killerPlayerId: killerPlayerId,
            killerPlayerName: killerPlayerName
        });

        emit TrophyMinted(tokenId, to, monsterId, monsterName, difficulty, killerPlayerId, killerPlayerName);
    }

    //==============================================================//
    //                     ADMIN FUNCTIONS                          //
    //==============================================================//
    function setAuthorizedMinter(address newMinter) external onlyOwner {
        authorizedMinter = newMinter;
    }

    //==============================================================//
    //                    INTERNAL FUNCTIONS                        //
    //==============================================================//
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
