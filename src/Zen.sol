// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/interfaces/IERC721.sol";

/// @title Zen (Red Bean Swap)
/// @author The Garden
contract Zen {
    /// >>>>>>>>>>>>>>>>>>>>>>>>>  CUSTOM ERRORS   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    error NonexistentTrade();

    error TimeExpired();

    error InvalidAction();

    error DeniedOwnership();

    /// >>>>>>>>>>>>>>>>>>>>>>>>>  METADATA   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    event SwapCreated(ZenSwap);

    event SwapAccepted(ZenSwap);

    event SwapUpdated(ZenSwap);

    event SwapCanceled(ZenSwap);

    /// @notice AzukiZen contract on mainnet
    IERC721 private constant IZen =
        IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    /// @dev Packed struct of swap data.
    /// @param offerTokens List of token IDs offered
    /// @param offerTokens List of token IDs requested in exchange
    /// @param counterParty Opposing party the swap is initiated with.
    /// @param createdAt UNIX Timestamp of swap creation.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    struct ZenSwap {
        uint256[] offerTokens;
        uint256[] counterTokens;
        address counterParty;
        uint64 createdAt;
        uint32 allotedTime;
    }

    /// @notice Maps offering party to their respective active swap
    mapping(address => ZenSwap) public activeSwaps;

    constructor() {}

    /// @notice Creates a new swap.
    /// @param offerTokens Token IDs offered by the offering party (caller).
    /// @param counterParty Opposing party the swap is initiated with.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    function initiateSwap(
        uint256[] memory offerTokens,
        address counterParty,
        uint256[] memory counterTokens,
        uint32 allotedTime
    ) public {
        if (allotedTime == 0) revert InvalidAction();
        if (allotedTime >= 365 days) revert InvalidAction();
        if (!_verifyOwnership(msg.sender, offerTokens))
            revert DeniedOwnership();
        if (!_verifyOwnership(counterParty, counterTokens))
            revert DeniedOwnership();

        ZenSwap memory swap = ZenSwap(
            offerTokens,
            counterTokens,
            counterParty,
            uint64(block.timestamp),
            allotedTime
        );

        activeSwaps[msg.sender] = swap;

        emit SwapCreated(swap);
    }

    /// @notice Accepts an existing swap.
    /// @param offerer Address of the offering party that initiated the swap
    function acceptSwap(address offerer) public {
        ZenSwap memory swap = activeSwaps[offerer];

        if (swap.counterParty != msg.sender) revert NonexistentTrade();
        if (block.timestamp > swap.createdAt + swap.allotedTime)
            revert TimeExpired();

        uint256 offererLength = swap.offerTokens.length;
        uint256 counterLength = swap.counterTokens.length;
        uint256[] memory offerTokens = swap.offerTokens;
        uint256[] memory counterTokens = swap.counterTokens;

        for (uint256 i; i < offererLength; ) {
            IZen.transferFrom(offerer, msg.sender, offerTokens[i]);

            unchecked {
                i++;
            }
        }

        for (uint256 i; i < counterLength; ) {
            IZen.transferFrom(msg.sender, offerer, counterTokens[i]);

            unchecked {
                i++;
            }
        }

        delete activeSwaps[offerer];

        emit SwapAccepted(swap);
    }

    /// @notice Batch verifies that the specified owner is the owner of all tokens.
    /// @param owner Specified owner of tokens.
    /// @param tokenIds List of token IDs.
    function _verifyOwnership(address owner, uint256[] memory tokenIds)
        internal
        view
        returns (bool success)
    {
        uint256 length = tokenIds.length;

        for (uint256 i = 0; i < length; ) {
            if (IZen.ownerOf(tokenIds[i]) != owner) return false;

            unchecked {
                i++;
            }
        }

        success = true;
    }

    /// @notice Gets the details of an existing swap.
    function getSwap(address offerer)
        public
        view
        returns (
            uint256[] memory offerTokens,
            uint256[] memory counterTokens,
            address counterParty,
            uint64 createdAt,
            uint32 allotedTime
        )
    {
        ZenSwap memory swap = activeSwaps[offerer];

        offerTokens = swap.offerTokens;
        counterTokens = swap.counterTokens;
        counterParty = swap.counterParty;
        createdAt = swap.createdAt;
        allotedTime = swap.allotedTime;
    }

    /// @notice Manually deletes existing swap.
    function cancelSwap() public {
        ZenSwap memory swap = activeSwaps[msg.sender];

        delete swap;

        emit SwapCanceled(swap);
    }
}
