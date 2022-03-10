// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/interfaces/IERC721.sol";
import "@openzeppelin/interfaces/IERC1155.sol";

error NonexistentTrade();
error TimeExpired();
error InvalidAction();
error DeniedOwnership();

/// @title Zen (Red Bean Swap)
/// @author The Garden
contract Zen {
    /// >>>>>>>>>>>>>>>>>>>>>>>>>  METADATA   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    event SwapCreated(ZenSwap);

    event SwapAccepted(ZenSwap);

    event SwapUpdated(ZenSwap);

    event SwapCanceled(ZenSwap);

        event RequesterAdded(ZenSwap);

    /// @notice Azuki contract on mainnet
    IERC721 private constant IAzuki =
        IERC721(0xED5AF388653567Af2F388E6224dC7C4b3241C544);

    /// @notice BOBU contract on mainnet
    IERC1155 private constant IBobu =
        IERC1155(0x2079812353E2C9409a788FBF5f383fa62aD85bE8);

    /// @dev Packed struct of swap data.
    /// @param offerTokens List of token IDs offered
    /// @param offerTokens List of token IDs requested in exchange
    /// @param counterParty Opposing party the swap is initiated with.
    /// @param createdAt UNIX Timestamp of swap creation.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    struct ZenSwap {
        uint256[] offerTokens721;
        uint256 offerTokens1155;
        uint256[] counterTokens721;
        uint256 counterTokens1155;
        address counterParty;
        uint64 createdAt;
        uint32 allotedTime;
    }

    /// @notice Maps offering party to their respective active swap
    mapping(address => ZenSwap) public activeSwaps;

    /// @notice Maps user to addresses requesting swap
    mapping(address => address[]) public incomingRequesters;

    /// @notice Maps user's requester to index within above array
    mapping(address => mapping(address => uint256)) public indexOfRequester;

    constructor() {}

    /// @notice Creates a new swap.
    /// @param offerTokens721 ERC721 Token IDs offered by the offering party (caller).
    /// @param offerTokens1155 ERC1155 quantity of Bobu Token ID #1
    /// @param counterParty Opposing party the swap is initiated with.
    /// @param counterTokens721 ERC721 Token IDs requested from the counter party.
    /// @param counterTokens1155 ERC1155 quantity of Bobu Token ID #1 request from the counter party.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    function createSwap(
        uint256[] memory offerTokens721,
        uint256 offerTokens1155,
        address counterParty,
        uint256[] memory counterTokens721,
        uint256 counterTokens1155,
        uint32 allotedTime
    ) public {
        if (offerTokens721.length == 0 && counterTokens721.length == 0)
            revert InvalidAction();
        if (allotedTime == 0) revert InvalidAction();
        if (allotedTime >= 365 days) revert InvalidAction();
        if (!_verifyOwnership721(msg.sender, offerTokens721))
            revert DeniedOwnership();
        if (!_verifyOwnership721(counterParty, counterTokens721))
            revert DeniedOwnership();
        if (!_verifyOwnership1155(msg.sender, offerTokens1155))
            revert DeniedOwnership();
        if (!_verifyOwnership1155(counterParty, counterTokens1155))
            revert DeniedOwnership();

        ZenSwap memory swap = ZenSwap(
            offerTokens721,
            offerTokens1155,
            counterTokens721,
            counterTokens1155,
            counterParty,
            uint64(block.timestamp),
            allotedTime
        );

        activeSwaps[msg.sender] = swap;
        incomingRequesters[counterParty] = incomingRequesters[counterParty].push(msg.sender);

        emit SwapCreated(swap);
    }

    /// @notice Accepts an existing swap.
    /// @param offerer Address of the offering party that initiated the swap
    function acceptSwap(address offerer) public {
        ZenSwap memory swap = activeSwaps[offerer];

        if (swap.counterParty != msg.sender) revert NonexistentTrade();
        if (block.timestamp > swap.createdAt + swap.allotedTime)
            revert TimeExpired();

        delete activeSwaps[offerer];

        _swapERC721(swap, offerer);
        _swapERC1155(swap, offerer);

        incomingRequesters[counterParty] = incomingRequesters[counterParty].push(msg.sender);
        _removeRequester(msg.sender);

        emit SwapAccepted(swap);
    }

    function _removeRequester(address requester) internal {
        uint256 index = indexOfRequester[msg.sender][requester];

        address[] requesters = incomingRequesters[requester];
        requesters[index] = requesters[requester.length - 1];
        requesters.pop();
    }

    /// @notice Swaps ERC721 contents
    /// @param swap ZenSwap object containing all swap data
    /// @param offerer User that created the swap
    /// @dev `msg.sender` is the user accepting the swap
    function _swapERC721(ZenSwap memory swap, address offerer) internal {
        uint256 offererLength721 = swap.offerTokens721.length;
        uint256 counterLength721 = swap.counterTokens721.length;

        uint256[] memory offerTokens721 = swap.offerTokens721;
        uint256[] memory counterTokens721 = swap.counterTokens721;

        for (uint256 i; i < offererLength721; ) {
            IAzuki.transferFrom(offerer, msg.sender, offerTokens721[i]);

            unchecked {
                i++;
            }
        }

        for (uint256 i; i < counterLength721; ) {
            IAzuki.transferFrom(msg.sender, offerer, counterTokens721[i]);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Swaps ERC1155 contents
    /// @param swap ZenSwap object containing all swap data
    /// @param offerer User that created the swap
    /// @dev `msg.sender` is the user accepting the swap
    function _swapERC1155(ZenSwap memory swap, address offerer) internal {
        uint256 offererQuantity1155 = swap.offerTokens1155;
        uint256 counterQuantity1155 = swap.counterTokens1155;

        if (offererQuantity1155 != 0) {
            IBobu.safeTransferFrom(
                offerer,
                msg.sender,
                1,
                offererQuantity1155,
                ""
            );
        }

        if (counterQuantity1155 != 0) {
            IBobu.safeTransferFrom(
                msg.sender,
                offerer,
                1,
                counterQuantity1155,
                ""
            );
        }
    }

    /// @notice Batch verifies that the specified owner is the owner of all ERC721 tokens.
    /// @param owner Specified owner of tokens.
    /// @param tokenIds List of token IDs.
    function _verifyOwnership721(address owner, uint256[] memory tokenIds)
        internal
        view
        returns (bool success)
    {
        uint256 length = tokenIds.length;

        for (uint256 i = 0; i < length; ) {
            if (IAzuki.ownerOf(tokenIds[i]) != owner) return false;

            unchecked {
                i++;
            }
        }

        success = true;
    }

    /// @notice Batch verifies that the specified owner is the owner of all ERC1155 tokens.
    /// @param owner Specified owner of tokens.
    /// @param tokenQuantity Amount of Bobu tokens
    function _verifyOwnership1155(address owner, uint256 tokenQuantity)
        internal
        view
        returns (bool)
    {
        return IBobu.balanceOf(owner, 1) >= tokenQuantity;
    }

    /// @notice Gets the details of an existing swap.
    function getSwap(address offerer)
        external
        view
        returns (
            uint256[] memory offerTokens721,
            uint256 offerTokens1155,
            uint256[] memory counterTokens721,
            uint256 counterTokens1155,
            address counterParty,
            uint64 createdAt,
            uint32 allotedTime
        )
    {
        ZenSwap memory swap = activeSwaps[offerer];

        offerTokens721 = swap.offerTokens721;
        offerTokens1155 = swap.offerTokens1155;
        counterTokens721 = swap.counterTokens721;
        counterTokens1155 = swap.counterTokens1155;
        counterParty = swap.counterParty;
        createdAt = swap.createdAt;
        allotedTime = swap.allotedTime;
    }

    /// @notice Manually deletes existing swap.
    function cancelSwap() public {
        ZenSwap memory swap = activeSwaps[msg.sender];

        if (swap.counterParty == address(0x0)) revert InvalidAction();

        delete swap;

        emit SwapCanceled(swap);
    }
}
