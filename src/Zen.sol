// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/interfaces/IERC721.sol";

/// @title Zen
/// @author zkSoju <soju@zkrlabs.com>
contract Zen {
    error NonexistentTrade();
    error TimeExpired();

    event CreatedSwap(ZenSwap);
    event AcceptedSwap(ZenSwap);

    IERC721 private constant IZen =
        IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    struct ZenSwap {
        address counterParty;
        uint256[] offerTokens;
        uint256[] counterTokens;
        uint256 expiresAt;
    }

    mapping(address => ZenSwap) public activeSwaps;

    constructor() {}

    function initiateSwap(
        uint256[] memory offerTokens,
        address counterParty,
        uint256[] memory counterTokens
    ) public {
        ZenSwap memory swap = ZenSwap(
            counterParty,
            offerTokens,
            counterTokens,
            block.timestamp + 1 days
        );

        activeSwaps[msg.sender] = swap;

        emit CreatedSwap(swap);
    }

    function acceptSwap(address offerer) public {
        ZenSwap memory swap = activeSwaps[offerer];

        if (block.timestamp > swap.timestamp) revert TimeExpired();
        if (swap.counterParty != msg.sender) revert NonexistentTrade();

        uint256 offererLength = swap.offerTokens.length;
        uint256 counterLength = swap.counterTokens.length;
        uint256[] memory offerTokens = swap.offerTokens;
        uint256[] memory counterTokens = swap.counterTokens;

        for (uint256 i = 0; i < offererLength; ) {
            IZen.transferFrom(offerer, msg.sender, offerTokens[i]);

            unchecked {
                i++;
            }
        }

        for (uint256 i = 0; i < counterLength; ) {
            IZen.transferFrom(msg.sender, offerer, counterTokens[i]);

            unchecked {
                i++;
            }
        }

        emit AcceptedSwap(swap);
    }

    function getTrade(address offerer) public view returns (address to) {
        return activeSwaps[offerer].counterParty;
    }

    function cancelTrade() public {}
}
