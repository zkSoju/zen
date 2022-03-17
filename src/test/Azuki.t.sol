// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockAzuki} from "./utils/mocks/MockAzuki.sol";

import "@openzeppelin/interfaces/IERC721.sol";

import "@openzeppelin/interfaces/IERC1155.sol";

contract AzukiTest is DSTestPlus {
    MockAzuki azuki;

    function setUp() public {
        azuki = new MockAzuki();
    }

    function testMint() public {
        startHoax(address(1337), address(1337));

        azuki.mint();

        emit log_string(azuki.tokenURI(0));
    }
}
