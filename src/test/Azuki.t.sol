// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Azuki} from "../mocks/Azuki.sol";

import "@openzeppelin/interfaces/IERC721.sol";

import "@openzeppelin/interfaces/IERC1155.sol";

contract ZenTest is DSTestPlus {
    Azuki azuki;

    function setUp() public {
        azuki = new Azuki();
    }

    function testMint() public {
        startHoax(address(1337), address(1337));

        azuki.mint();
    }
}
