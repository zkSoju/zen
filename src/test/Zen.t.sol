// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {Zen} from "../Zen.sol";
import {Azuki} from "../Azuki.sol";

import "@openzeppelin/interfaces/IERC721.sol";

import "@openzeppelin/interfaces/IERC1155.sol";

contract ZenTest is DSTestPlus {
    Azuki azuki;
    Zen zen;
    Zen mockZen;

    /// @notice Azuki contract on mainnet
    IERC721 private constant IAzuki =
        IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    /// @notice BOBU contract on mainnet
    IERC1155 private constant IBobu =
        IERC1155(0x2079812353E2C9409a788FBF5f383fa62aD85bE8);

    address zenWhale1 = 0x8ffa85a0c59Cf23967eb31C060B2ca3A920276E1;
    address zenWhale2 = 0x07cc65Ec4de72Fdf7d2B6C39Fd80c4EA4706215B;

    address bobuWhale1 = 0x103fC5759305e59DBE6C3355d11C35A213A5252C;

    function setUp() public {
        azuki = new Azuki();
        zen = new Zen(IAzuki, IBobu);

        // using mock contracts
        mockZen = new Zen(azuki, IBobu);

        vm.label(zenWhale1, "Azuki Whale #1");
        vm.label(zenWhale1, "Azuki Whale #2");
        vm.label(bobuWhale1, "Bobu Whale #1");
    }

    function testMockSwap() public {
        /// Imitate as offering party
        hoax(zenWhale1, zenWhale1);

        azuki.mint();

        /// Imitate as counter party
        hoax(zenWhale2, zenWhale2);

        azuki.mint();

        uint256 zenWhale1Balance = azuki.balanceOf(zenWhale1);
        uint256 zenWhale2Balance = azuki.balanceOf(zenWhale2);

        /// Assert token balance of accounts are greater than 0
        assert(zenWhale1Balance > 0);
        assert(zenWhale1Balance > 0);

        /// Assert ownership of tokens
        assertEq(azuki.ownerOf(0), address(zenWhale1));
        assertEq(azuki.ownerOf(1), address(zenWhale2));

        /// Initialize arguments for swap
        uint256[] memory whale1Tokens = new uint256[](1);
        whale1Tokens[0] = 0;

        uint256[] memory whale2Tokens = new uint256[](1);
        whale2Tokens[0] = 1;

        startHoax(zenWhale1, zenWhale1);

        /// Set approval for operating contract
        azuki.setApprovalForAll(address(zen), true);

        /// Initiate swap
        mockZen.createSwap(whale1Tokens, 0, zenWhale2, whale2Tokens, 0, 1 days);

        vm.stopPrank();
    }

    function testSingleSwap721() public {
        _createSwap();

        vm.stopPrank();

        /// Imitate as counter party
        startHoax(zenWhale2, zenWhale2);

        /// Accept existing trade
        IAzuki.setApprovalForAll(address(zen), true);
        zen.acceptSwap(zenWhale1);

        /// Assert that swap is deleted from mapping after successful swap
        (, , , , address counterParty, , ) = zen.getSwap(zenWhale1);
        assert(counterParty == address(0x0));

        vm.stopPrank();

        /// Assert token swap is successful
        assertEq(IAzuki.ownerOf(8024), address(zenWhale1));
    }

    function testMultiSwap721() public {
        /// Initialize arguments for swap
        uint256[] memory whale1Tokens = new uint256[](2);
        whale1Tokens[0] = 7782;
        whale1Tokens[1] = 9909;

        uint256[] memory whale2Tokens = new uint256[](2);
        whale2Tokens[0] = 8024;
        whale2Tokens[1] = 6365;

        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        uint256 zenWhale1Balance = IAzuki.balanceOf(zenWhale1);
        uint256 zenWhale2Balance = IAzuki.balanceOf(zenWhale2);

        /// Assert token balance of accounts are greater than 0
        assert(zenWhale1Balance > 0);
        assert(zenWhale1Balance > 0);

        /// Assert ownership of tokens
        assertEq(IAzuki.ownerOf(7782), address(zenWhale1));
        assertEq(IAzuki.ownerOf(8024), address(zenWhale2));

        /// Set approval for operating contract
        IAzuki.setApprovalForAll(address(zen), true);

        /// Initiate swap
        zen.createSwap(whale1Tokens, 0, zenWhale2, whale2Tokens, 0, 1 days);

        vm.stopPrank();

        /// Imitate as counter party
        startHoax(zenWhale2, zenWhale2);

        /// Accept existing trade
        IAzuki.setApprovalForAll(address(zen), true);
        zen.acceptSwap(zenWhale1);

        vm.stopPrank();

        /// Assert that swap is deleted from mapping after successful swap
        (, , , , address counterParty, , ) = zen.getSwap(zenWhale1);
        assert(counterParty == address(0x0));

        /// Assert token swap is successful
        assertEq(IAzuki.ownerOf(8024), address(zenWhale1));
        assertEq(IAzuki.ownerOf(7782), address(zenWhale2));
    }

    function testCompositeSwap() public {
        /// Initialize arguments for swap
        uint256[] memory bobuWhale1Tokens = new uint256[](2);
        bobuWhale1Tokens[0] = 1610;
        bobuWhale1Tokens[1] = 4257;

        uint256 bobuQuantity = 20;

        emit log_uint(IBobu.balanceOf(bobuWhale1, 1));

        uint256[] memory whale1Tokens = new uint256[](2);
        whale1Tokens[0] = 7782;
        whale1Tokens[1] = 9909;

        startHoax(bobuWhale1, bobuWhale1);

        /// Set approval for operating contract
        IAzuki.setApprovalForAll(address(zen), true);
        IBobu.setApprovalForAll(address(zen), true);

        /// Create swap for
        /// `bobuWhale1Tokens` + `bobuQuantity` BOBU <-> `whale1Tokens`
        zen.createSwap(
            bobuWhale1Tokens,
            bobuQuantity,
            zenWhale1,
            whale1Tokens,
            0,
            1 days
        );

        vm.stopPrank();

        /// Start hoax
        startHoax(zenWhale1, zenWhale1);

        /// Set approval for operating contract
        IAzuki.setApprovalForAll(address(zen), true);

        /// Successful swap
        zen.acceptSwap(bobuWhale1);

        assert(IBobu.balanceOf(zenWhale1, 1) == bobuQuantity);
    }

    function testCancelSwap() public {
        startHoax(zenWhale1, zenWhale1);

        /// Add more tests
        _createSwap();
        zen.cancelSwap();

        (, , , , address counterParty, , ) = zen.getSwap(zenWhale1);
        assert(counterParty == address(0x0));

        /// Expect revert for non-existent trade
        vm.expectRevert(abi.encodePacked(bytes4(keccak256("InvalidAction()"))));
        zen.cancelSwap();
    }

    function testInvalidSwaps() public {
        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        /// Set approval for operating contract
        IAzuki.setApprovalForAll(address(zen), true);

        vm.stopPrank();

        /// Imitate as malicious party
        startHoax(address(1337), address(1337));

        /// Expect revert for external party trying to accept swap
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("NonexistentTrade()")))
        );
        zen.acceptSwap(zenWhale1);

        uint256[] memory whale1Tokens = new uint256[](2);
        whale1Tokens[0] = 7782;
        whale1Tokens[1] = 9909;

        uint256[] memory fakeTokens = new uint256[](1);
        fakeTokens[0] = 0;

        /// Assert address does not own tokens
        assert(IAzuki.ownerOf(fakeTokens[0]) != address(1337));

        /// Expect revert for creating a swap with tokens offerer does not own
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("DeniedOwnership()")))
        );
        zen.createSwap(fakeTokens, 0, zenWhale1, whale1Tokens, 0, 1 days);

        vm.stopPrank();

        startHoax(zenWhale1, zenWhale1);

        /// Expect revert for creating a swap with tokens counter party does not own
        vm.expectRevert(
            abi.encodePacked(bytes4(keccak256("DeniedOwnership()")))
        );
        zen.createSwap(whale1Tokens, 0, address(1337), fakeTokens, 0, 1 days);
    }

    function testRequesters() public {
        _createSwap();

        address requester = zen.incomingRequesters(zenWhale2, 0);

        emit log_address(requester);
    }

    function _createSwap() internal {
        /// Initialize arguments for swap
        uint256[] memory whale1Tokens = new uint256[](2);
        whale1Tokens[0] = 7782;
        whale1Tokens[1] = 9909;

        uint256[] memory whale2Tokens = new uint256[](2);
        whale2Tokens[0] = 8024;
        whale2Tokens[1] = 6365;

        /// Imitate as offering party
        startHoax(zenWhale1, zenWhale1);

        uint256 zenWhale1Balance = IAzuki.balanceOf(zenWhale1);
        uint256 zenWhale2Balance = IAzuki.balanceOf(zenWhale2);

        /// Assert token balance of accounts are greater than 0
        assert(zenWhale1Balance > 0);
        assert(zenWhale1Balance > 0);

        /// Assert ownership of tokens
        assertEq(IAzuki.ownerOf(7782), address(zenWhale1));
        assertEq(IAzuki.ownerOf(8024), address(zenWhale2));

        /// Set approval for operating contract
        IAzuki.setApprovalForAll(address(zen), true);

        /// Initiate swap
        zen.createSwap(whale1Tokens, 0, zenWhale2, whale2Tokens, 0, 1 days);
    }
}
