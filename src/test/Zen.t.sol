// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Zen} from "../Zen.sol";

import "@openzeppelin/interfaces/IERC721.sol";

contract ZenTest is DSTestPlus {
    Zen zen;

    address private constant azukiContract =
        0xED5AF388653567Af2F388E6224dC7C4b3241C544;

    IERC721 azuki = IERC721(azukiContract);

    address zenWhale1 = 0x8ffa85a0c59Cf23967eb31C060B2ca3A920276E1;
    address zenWhale2 = 0x07cc65Ec4de72Fdf7d2B6C39Fd80c4EA4706215B;

    /// Initialize arguments for swap
    uint256[] private whale1Tokens = new uint256[](2);

    uint256[] private whale2Tokens = new uint256[](2);

    function setUp() public {
        zen = new Zen();

        whale1Tokens[0] = 7782;
        whale1Tokens[1] = 9909;

        whale2Tokens[0] = 8024;
        whale2Tokens[1] = 6365;

        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        /// Set approval for operating contract
        azuki.setApprovalForAll(address(zen), true);

        /// Setup a single valid swap
        zen.initiateSwap(whale1Tokens, zenWhale2, whale2Tokens, 1 days);

        vm.stopPrank();
    }

    function testSwap() public {
        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        uint256 zenWhale1Balance = azuki.balanceOf(zenWhale1);
        uint256 zenWhale2Balance = azuki.balanceOf(zenWhale2);

        /// Assert token balance of accounts are greater than 0
        assert(zenWhale1Balance > 0);
        assert(zenWhale1Balance > 0);

        /// Assert ownership of tokens
        assertEq(azuki.ownerOf(7782), address(zenWhale1));
        assertEq(azuki.ownerOf(8024), address(zenWhale2));

        /// Set approval for operating contract
        azuki.setApprovalForAll(address(zen), true);

        /// Initiate swap
        zen.initiateSwap(whale1Tokens, zenWhale2, whale2Tokens, 1 days);

        vm.stopPrank();

        /// Get active swap from offering party
        (, , address counterParty, , ) = zen.getSwap(zenWhale1);
        emit log_address(counterParty);

        /// Imitate as counter party
        startHoax(zenWhale2, zenWhale2);

        /// Accept existing trade
        azuki.setApprovalForAll(address(zen), true);
        zen.acceptSwap(zenWhale1);

        vm.stopPrank();

        /// Assert token swap is successful
        assertEq(azuki.ownerOf(8024), address(zenWhale1));
        assertEq(azuki.ownerOf(7782), address(zenWhale2));
    }

    function testSwapCreate() public {
        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        /// Set approval for operating contract
        azuki.setApprovalForAll(address(zen), true);

        /// Initiate swap
        zen.initiateSwap(whale1Tokens, zenWhale2, whale2Tokens, 1 days);

        vm.stopPrank();
    }

    function testSwapAccept() public {
        /// Imitate as counter party
        startHoax(zenWhale2, zenWhale2);

        /// Accept existing trade
        azuki.setApprovalForAll(address(zen), true);
        zen.acceptSwap(zenWhale1);

        vm.stopPrank();
    }

    function testInvalidSwaps() public {
        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        /// Set approval for operating contract
        azuki.setApprovalForAll(address(zen), true);

        vm.stopPrank();

        /// Imitate as malicious party
        startHoax(address(1337), address(1337));

        /// Expect revert for external party trying to accept swap
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("NonexistentTrade()")))
        );
        zen.acceptSwap(zenWhale1);
    }
}
