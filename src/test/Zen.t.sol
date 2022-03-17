// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Zen} from "../Zen.sol";
import {MockAzuki} from "./utils/mocks/MockAzuki.sol";
import {MockBobu} from "./utils/mocks/MockBobu.sol";
import {IZen} from "../interfaces/IZen.sol";

contract ZenTest is DSTestPlus {
    MockAzuki azuki;
    MockBobu bobu;
    Zen zen;
    IZen zenInterface;

    function setUp() public {
        azuki = new MockAzuki();
        bobu = new MockBobu();

        zen = new Zen(address(azuki), address(bobu));
        zenInterface = IZen(address(zen));

        vm.label(address(0xBEEF), "Offerer");
        vm.label(address(1337), "Requester");
    }

    function testMockSwap() public {
        _createSwap();

        IZen.ZenSwap memory swap = zenInterface.getSwap(0, address(0xBEEF));

        assert(swap.requestFrom == address(1337));
    }

    function testMockSwapComposite() public {
        _createSwapComposite();

        IZen.ZenSwap memory swap = zenInterface.getSwap(0, address(0xBEEF));

        assert(swap.requestFrom == address(1337));
    }

    function testAcceptSwap() public {
        _createSwap();

        startHoax(address(1337), address(1337));

        azuki.setApprovalForAll(address(zen), true);
        bobu.setApprovalForAll(address(zen), true);

        zen.acceptSwap(0, address(0xBEEF));

        vm.stopPrank();
    }

    function testAcceptSwapComposite() public {
        _createSwapComposite();

        startHoax(address(1337), address(1337));

        azuki.setApprovalForAll(address(zen), true);
        bobu.setApprovalForAll(address(zen), true);

        zen.acceptSwap(0, address(0xBEEF));

        vm.stopPrank();
    }

    function testEditSwap() public {
        _createSwapComposite();

        startHoax(address(0xBEEF), address(0xBEEF));

        IZen.ZenSwap memory oldSwap = zenInterface.getSwap(0, address(0xBEEF));

        zen.extendAllotedTime(0, 86400);

        IZen.ZenSwap memory newSwap = zenInterface.getSwap(0, address(0xBEEF));

        assert(oldSwap.allotedTime + 86400 == newSwap.allotedTime);

        vm.stopPrank();
    }

    function testCancelSwap() public {
        _createSwapComposite();

        startHoax(address(0xBEEF), address(0xBEEF));

        zen.cancelSwap(0);

        IZen.ZenSwap memory swap = zenInterface.getSwap(0, address(0xBEEF));

        assert(swap.requestFrom == address(1337));
        assert(swap.status == IZen.swapStatus.INACTIVE);

        vm.stopPrank();
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

        uint256[] memory offer = new uint256[](1);
        offer[0] = 1;

        uint256[] memory request = new uint256[](1);
        request[0] = 0;

        zen.createSwap(offer, 0, address(1337), request, 0, 43200);
    }

    function _createSwapComposite() internal {
        startHoax(address(1337), address(1337));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        bobu.mint(1000);

        assert(bobu.balanceOf(address(1337), 0) == uint256(1000));
        assert(azuki.balanceOf(address(1337)) == uint256(1));

        vm.stopPrank();

        startHoax(address(0xBEEF), address(0xBEEF));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        bobu.mint(1000);

        assert(azuki.balanceOf(address(1337)) == uint256(1));

        uint256[] memory offer = new uint256[](1);
        offer[0] = 1;

        uint256[] memory request = new uint256[](1);
        request[0] = 0;

        zen.createSwap(offer, 0, address(1337), request, 1000, 43200);
    }
}
