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

    function testSingleSwap() public {
        _createSwap();

        startHoax(address(1337), address(1337));

        Zen.Swap memory swap = zen.getSwapSingle(0, address(0xBEEF));

        assert(swap.recipient == address(1337));

        zen.acceptSwap(0, address(0xBEEF));

        assert(
            zen.getSwapSingle(0, address(0xBEEF)).status ==
                Zen.SwapStatus.COMPLETE
        );

        assert(azuki.ownerOf(0) == address(0xBEEF));
        assert(azuki.ownerOf(1) == address(1337));

        vm.stopPrank();
    }

    function testIllegitimateSwap() public {
        startHoax(address(1337), address(1337));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        assert(azuki.balanceOf(address(1337)) == uint256(1));
        assert(azuki.ownerOf(0) == address(1337));

        vm.stopPrank();

        startHoax(address(0xBEEF), address(0xBEEF));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        assert(azuki.balanceOf(address(0xBEEF)) == uint256(1));
        assert(azuki.ownerOf(1) == address(0xBEEF));

        Zen.Token[] memory offer = new Zen.Token[](1);
        uint256[] memory offerTokens = new uint256[](1);
        offerTokens[0] = 0;
        offer[0] = Zen.Token(address(azuki), offerTokens, new uint256[](0));

        Zen.Token[] memory request = new Zen.Token[](1);
        uint256[] memory requestTokens = new uint256[](1);
        requestTokens[0] = 1;
        request[0] = Zen.Token(address(azuki), requestTokens, new uint256[](0));

        zen.createSwap(offer, request, address(1337), 43200);

        vm.stopPrank();

        startHoax(address(1337), address(1337));

        vm.expectRevert(
            bytes4(keccak256("ERC721: transfer from incorrect owner"))
        );
        zen.acceptSwap(0, address(0xBEEF));

        vm.stopPrank();
    }

    function testCreateSwap() public {
        _createSwap();

        assert(azuki.ownerOf(0) == address(1337));
        assert(azuki.ownerOf(1) == address(0xBEEF));
        assert(
            zen.getSwapSingle(0, address(0xBEEF)).status ==
                Zen.SwapStatus.ACTIVE
        );
    }

    function _createSwap() internal {
        startHoax(address(1337), address(1337));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        assert(azuki.balanceOf(address(1337)) == uint256(1));
        assert(azuki.ownerOf(0) == address(1337));

        vm.stopPrank();

        startHoax(address(0xBEEF), address(0xBEEF));

        azuki.mint();
        azuki.setApprovalForAll(address(zen), true);

        assert(azuki.balanceOf(address(0xBEEF)) == uint256(1));
        assert(azuki.ownerOf(1) == address(0xBEEF));

        Zen.Token[] memory offer = new Zen.Token[](1);
        uint256[] memory offerTokens = new uint256[](1);
        offerTokens[0] = 1;
        offer[0] = Zen.Token(address(azuki), offerTokens, new uint256[](0));

        Zen.Token[] memory request = new Zen.Token[](1);
        uint256[] memory requestTokens = new uint256[](1);
        requestTokens[0] = 0;
        request[0] = Zen.Token(address(azuki), requestTokens, new uint256[](0));

        zen.createSwap(offer, request, address(1337), 43200);

        vm.stopPrank();
    }
}
