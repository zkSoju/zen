// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Zen} from "../Zen.sol";
import {MockAzuki} from "./utils/mocks/MockAzuki.sol";
import {MockBobu} from "./utils/mocks/MockBobu.sol";

contract ZenTest is DSTestPlus {
    MockAzuki azuki;
    MockBobu bobu;
    Zen zen;

    function setUp() public {
        azuki = new MockAzuki();
        bobu = new MockBobu();

        zen = new Zen();

        vm.label(address(0xBEEF), "Offerer");
        vm.label(address(1337), "Requester");
    }

    function testMockSwap() public {
        _createSwap();
    }

    function _createSwap() internal {
        startHoax(address(1337), address(1337));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        assert(azuki.balanceOf(address(1337)) == uint256(1));

        vm.stopPrank();

        startHoax(address(0xBEEF), address(0xBEEF));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        assert(azuki.balanceOf(address(1337)) == uint256(1));

        Zen.Token[] memory offer = new Zen.Token[](1);
        offer[0] = Zen.Token(address(azuki), 0, 1);

        Zen.Token[] memory request = new Zen.Token[](1);
        request[0] = Zen.Token(address(azuki), 0, 1);

        zen.createSwap(offer, request, address(1337), 43200);
    }
}
