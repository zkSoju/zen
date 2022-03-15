// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {MockBobu} from "./utils/mocks/MockBobu.sol";

contract BobuTest is DSTestPlus {
    MockBobu bobu;

    function setUp() public {
        bobu = new MockBobu();
    }

    function testMint() public {
        startHoax(address(1337), address(1337));

        bobu.mint(1337);

        assert(bobu.balanceOf(address(1337), 0) == uint256(1337));
    }
}
