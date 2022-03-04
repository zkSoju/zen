// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Zen} from "../Zen.sol";

import "@openzeppelin/interfaces/IERC721.sol";

contract ZenTest is DSTestPlus {
    Zen zen;

    struct zenSwap {
        address counterParty;
        uint256[] initTokens;
        uint256[] counterTokens;
        uint256 expiresAt;
    }

    address private constant azukiContract =
        0xED5AF388653567Af2F388E6224dC7C4b3241C544;

    IERC721 azuki = IERC721(azukiContract);

    address zenWhale1 = 0x8ffa85a0c59Cf23967eb31C060B2ca3A920276E1;
    address zenWhale2 = 0x07cc65Ec4de72Fdf7d2B6C39Fd80c4EA4706215B;

    function setUp() public {
        zen = new Zen();
    }

    function testTrade() public {
        startHoax(zenWhale1, zenWhale1);

        uint256 zenWhale1Balance = azuki.balanceOf(zenWhale1);
        uint256 zenWhale2Balance = azuki.balanceOf(zenWhale2);

        emit log_uint(zenWhale1Balance);

        emit log_uint(zenWhale2Balance);

        uint256[] memory whale1Tokens = new uint256[](2);
        whale1Tokens[0] = 7782;
        whale1Tokens[1] = 9909;

        uint256[] memory whale2Tokens = new uint256[](2);
        whale2Tokens[0] = 8024;
        whale2Tokens[1] = 6365;

        assertEq(azuki.ownerOf(7782), address(zenWhale1));
        assertEq(azuki.ownerOf(8024), address(zenWhale2));

        azuki.setApprovalForAll(address(zen), true);
        zen.initiateSwap(whale1Tokens, zenWhale2, whale2Tokens);

        vm.stopPrank();

        emit log_address(zen.getTrade(zenWhale1));

        startHoax(zenWhale2, zenWhale2);

        azuki.setApprovalForAll(address(zen), true);
        zen.acceptSwap(zenWhale1);

        assertEq(azuki.ownerOf(8024), address(zenWhale1));
        assertEq(azuki.ownerOf(7782), address(zenWhale2));
    }
}
