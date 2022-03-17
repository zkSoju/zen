// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "./interfaces/IERC721.sol";
import "./interfaces/IERC1155.sol";

error InactiveSwap();
error InvalidAction();
error AlreadyCompleted();
error InvalidReceipient();
error NotAuthorized();

/// @title Zen (Red Bean Swap)
/// @author The Garden
contract Zen {
    /// >>>>>>>>>>>>>>>>>>>>>>>>>  METADATA   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    /// @notice Azuki contract on mainnet
    IERC721 private immutable azuki;

    /// @notice BOBU contract on mainnet
    IERC1155 private immutable bobu;

    uint256 private currentSwapId;

    enum swapStatus {
        ACTIVE,
        COMPLETE,
        INACTIVE
    }

    /// @dev Packed struct of swap data.
    /// @param offerTokens List of token IDs offered
    /// @param offerTokens List of token IDs requested in exchange
    /// @param to Opposing party the swap is initiated with.
    /// @param createdAt UNIX Timestamp of swap creation.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    struct OutgoingSwap {
        uint256 id;
        uint256[] offerTokens721;
        uint256 offerTokens1155;
        uint256[] requestTokens721;
        uint256 requestTokens1155;
        address to;
        uint64 createdAt;
        uint24 allotedTime;
        swapStatus status;
    }

    struct IncomingSwap {
        uint256 id;
        address from;
    }

    /// @notice Maps user to open swaps
    mapping(address => OutgoingSwap[]) public outgoingSwaps;

    /// @notice Maps user address to incoming swaps
    mapping(address => IncomingSwap[]) public incomingSwaps;

    /// @notice Maps swap IDs to index of swap in userSwap
    mapping(uint256 => uint256) public getSwapIndex;

    constructor(address _azuki, address _bobu) {
        azuki = IERC721(_azuki);
        bobu = IERC1155(_bobu);
    }

    /// @notice Creates a new swap.
    /// @param offerTokens721 ERC721 Token IDs offered by the offering party (caller).
    /// @param offerTokens1155 ERC1155 quantity of Bobu Token ID #1
    /// @param to Opposing party the swap is initiated with.
    /// @param requestTokens721 ERC721 Token IDs requested from the counter party.
    /// @param requestTokens1155 ERC1155 quantity of Bobu Token ID #1 request from the counter party.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    function createSwap(
        uint256[] calldata offerTokens721,
        uint256 offerTokens1155,
        address to,
        uint256[] calldata requestTokens721,
        uint256 requestTokens1155,
        uint24 allotedTime
    ) external {
        if (offerTokens721.length == 0 && requestTokens721.length == 0)
            revert InvalidAction();
        if (allotedTime == 0) revert InvalidAction();
        if (allotedTime >= 365 days) revert InvalidAction();
        if (to == address(0)) revert InvalidAction();
        if (!_verifyOwnership721(msg.sender, offerTokens721))
            revert NotAuthorized();
        if (!_verifyOwnership721(to, requestTokens721)) revert NotAuthorized();
        if (
            offerTokens1155 != 0 &&
            !_verifyOwnership1155(msg.sender, offerTokens1155)
        ) revert NotAuthorized();
        if (
            requestTokens1155 != 0 &&
            !_verifyOwnership1155(to, requestTokens1155)
        ) revert NotAuthorized();

        OutgoingSwap memory outgoingSwap = OutgoingSwap(
            currentSwapId,
            offerTokens721,
            offerTokens1155,
            requestTokens721,
            requestTokens1155,
            to,
            uint64(block.timestamp),
            allotedTime,
            swapStatus.ACTIVE
        );

        getSwapIndex[currentSwapId] = outgoingSwaps[msg.sender].length;
        outgoingSwaps[msg.sender].push(outgoingSwap);

        IncomingSwap memory incomingSwap = IncomingSwap(
            currentSwapId,
            msg.sender
        );

        incomingSwaps[to].push(incomingSwap);

        currentSwapId++;
    }

    /// @notice Accepts an existing swap.
    /// @param offerer Address of the offering party that initiated the swap
    /// @param id ID of the existing swap
    function acceptSwap(uint256 id, address offerer) external {
        uint256 swapIndex = getSwapIndex[id];
        OutgoingSwap memory swap = outgoingSwaps[offerer][swapIndex];

        if (swap.status == swapStatus.INACTIVE) revert InactiveSwap();
        if (swap.status == swapStatus.COMPLETE) revert AlreadyCompleted();
        if (swap.to != msg.sender) revert InvalidReceipient();
        if (block.timestamp > swap.createdAt + swap.allotedTime)
            revert InactiveSwap();

        outgoingSwaps[offerer][swapIndex].status = swapStatus.COMPLETE;
        _swapERC721(swap, offerer);
        if (!(swap.offerTokens1155 == 0 || swap.requestTokens1155 == 0)) {
            _swapERC1155(swap, offerer);
        }
    }

    /// @notice Swaps ERC721 contents
    /// @param swap ZenSwap object containing all swap data
    /// @param offerer User that created the swap
    /// @dev `msg.sender` is the user accepting the swap
    function _swapERC721(OutgoingSwap memory swap, address offerer) internal {
        uint256 offererLength721 = swap.offerTokens721.length;
        uint256 requestLength721 = swap.requestTokens721.length;

        uint256[] memory offerTokens721 = swap.offerTokens721;
        uint256[] memory requestTokens721 = swap.requestTokens721;

        for (uint256 i; i < offererLength721; ) {
            azuki.transferFrom(offerer, msg.sender, offerTokens721[i]);

            unchecked {
                i++;
            }
        }

        for (uint256 i; i < requestLength721; ) {
            azuki.transferFrom(msg.sender, offerer, requestTokens721[i]);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Swaps ERC1155 contents
    /// @param swap ZenSwap object containing all swap data
    /// @param offerer User that created the swap
    /// @dev `msg.sender` is the user accepting the swap
    function _swapERC1155(OutgoingSwap memory swap, address offerer) internal {
        uint256 offererQuantity1155 = swap.offerTokens1155;
        uint256 requestQuantity1155 = swap.requestTokens1155;

        if (offererQuantity1155 != 0) {
            bobu.safeTransferFrom(
                offerer,
                msg.sender,
                0,
                offererQuantity1155,
                ""
            );
        }

        if (requestQuantity1155 != 0) {
            bobu.safeTransferFrom(
                msg.sender,
                offerer,
                0,
                requestQuantity1155,
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
        returns (bool)
    {
        uint256 length = tokenIds.length;

        for (uint256 i = 0; i < length; ) {
            if (azuki.ownerOf(tokenIds[i]) != owner) return false;

            unchecked {
                i++;
            }
        }

        return true;
    }

    /// @notice Batch verifies that the specified owner is the owner of all ERC1155 tokens.
    /// @param owner Specified owner of tokens.
    /// @param tokenQuantity Amount of Bobu tokens
    function _verifyOwnership1155(address owner, uint256 tokenQuantity)
        internal
        view
        returns (bool)
    {
        return bobu.balanceOf(owner, 0) >= tokenQuantity;
    }

    /// @notice Gets the details of an existing swap.
    function getSwap(uint256 id, address offerer)
        external
        view
        returns (OutgoingSwap memory)
    {
        return outgoingSwaps[offerer][getSwapIndex[id]];
    }

    /// @notice Gets all details of existing swaps.
    /// @param user User to fetch outgoing swaps for
    function getAllOutgoingSwaps(address user)
        external
        view
        returns (OutgoingSwap[] memory)
    {
        return outgoingSwaps[user];
    }

    /// @notice Gets all details of existing swaps.
    /// @param user User to fetch incoming swaps for
    function getAllIncomingSwaps(address user)
        external
        view
        returns (OutgoingSwap[] memory)
    {
        uint256 length = incomingSwaps[user].length;
        OutgoingSwap[] memory swaps = new OutgoingSwap[](length);

        for (uint256 i; i < length; ) {
            IncomingSwap memory swap = incomingSwaps[user][i];
            swaps[i] = outgoingSwaps[swap.from][getSwapIndex[swap.id]];
            unchecked {
                ++i;
            }
        }

        return swaps;
    }

    /// @notice Extends existing swap alloted time
    /// @param allotedTime Amount of time to increase swap alloted time for
    function extendAllotedTime(uint256 id, uint24 allotedTime) external {
        OutgoingSwap storage swap = outgoingSwaps[msg.sender][getSwapIndex[id]];

        if (swap.status == swapStatus.INACTIVE) revert InvalidAction();

        swap.allotedTime = swap.allotedTime + allotedTime;
    }

    /// @notice Manually deletes existing swap.
    function cancelSwap(uint256 id) external {
        OutgoingSwap storage swap = outgoingSwaps[msg.sender][getSwapIndex[id]];

        if (swap.status == swapStatus.INACTIVE) revert InvalidAction();

        swap.status = swapStatus.INACTIVE;
    }
}
