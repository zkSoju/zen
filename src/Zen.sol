// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/interfaces/IERC721.sol";

/// @title Zen
/// @author zkSoju <soju@zkrlabs.com>
contract Zen {
    error InvalidTrade();

    IERC721 IZen = IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    struct zenSwap {
        address counterParty;
        uint256[] initTokens;
        uint256[] counterTokens;
        uint256 expiresAt;
    }

    mapping(address => zenSwap) public activeSwaps;

    constructor() {}

    function initiateSwap(
        uint256[] memory initTokens,
        address from,
        uint256[] memory counterTokens
    ) public returns (bool success) {
        for (
            uint256 tokenId = initTokens[0];
            tokenId < initTokens.length;
            ++tokenId
        ) {
            IZen.approve(address(this), tokenId);
        }

        activeSwaps[msg.sender] = zenSwap(
            from,
            initTokens,
            counterTokens,
            block.timestamp + 1 days
        );

        success = true;
    }

    function acceptSwap(address from) public {
        zenSwap memory swap = activeSwaps[from];

        if (swap.counterParty != msg.sender) revert InvalidTrade();

        uint256 length = swap.counterTokens.length;

        for (
            uint256 tokenId = swap.counterTokens[0];
            tokenId < length;
            ++tokenId
        ) IZen.transferFrom(from, swap.counterParty, 1);
    }

    function cancelTrade() public {}
}
