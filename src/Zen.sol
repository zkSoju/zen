// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/interfaces/IERC165.sol";
import "@openzeppelin/interfaces/IERC20.sol";
import "@openzeppelin/interfaces/IERC721.sol";
import "@openzeppelin/interfaces/IERC1155.sol";

/// @title Zen
/// @author The Garden
contract Zen {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error InactiveSwap();
    error InvalidInput();
    error InvalidReceipient();
    error AlreadyCompleted();
    error NotAuthorized();
    error NoncompliantTokens();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SwapCreated(
        uint256 indexed swapId,
        address indexed sender,
        address indexed recipient
    );

    event SwapAccepted(
        uint256 indexed swapId,
        address indexed sender,
        address indexed recipient
    );

    event SwapCancelled(
        uint256 indexed swapId,
        address indexed sender,
        address indexed recipient
    );

    /// -----------------------------------------------------------------------
    /// Structs
    /// -----------------------------------------------------------------------

    struct Token {
        address contractAddress;
        uint256[] tokenIds;
        uint256[] tokenQuantities;
    }

    /// @param id The id of the swap
    /// @param recipient The opposing party the swap is interacting with.
    /// @param createdAt The timestamp of swap creation.
    /// @param allotedTime The time allocated for the swap.
    /// @param status The status that determines the state of the swap.
    struct Swap {
        uint256 id;
        address recipient;
        uint64 createdAt;
        uint24 allotedTime;
        SwapStatus status;
    }

    enum SwapStatus {
        ACTIVE,
        COMPLETE,
        INACTIVE
    }

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 private _currentSwapId;

    /// @notice Maps user to outgoing Swaps.
    mapping(address => Swap[]) public getSwaps;

    /// @notice Maps Swap id to array of Tokens offered.
    mapping(uint256 => Token[]) public getOfferTokens;

    /// @notice Maps Swap id to array of Tokens requested.
    mapping(uint256 => Token[]) public getRequestTokens;

    /// @notice Maps Swap id to index of Swap within Swap array.
    mapping(uint256 => uint256) public getSwapIndex;

    constructor() {}

    /// @notice Creates a new swap.
    /// @param offerTokens Tokens being offered.
    /// @param requestTokens Tokens being requested.
    /// @param recipient The recipient of the swap request.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    function createSwap(
        Token[] calldata offerTokens,
        Token[] calldata requestTokens,
        address recipient,
        uint256 allotedTime
    ) external {
        if (offerTokens.length == 0 && requestTokens.length == 0)
            revert InvalidInput();
        if (allotedTime == 0) revert InvalidInput();
        if (allotedTime >= 365 days) revert InvalidInput();
        if (recipient == address(0)) revert InvalidInput();

        uint256 offerLength = offerTokens.length;
        uint256 requestLength = requestTokens.length;

        for (uint256 i; i < offerLength; ) {
            getOfferTokens[_currentSwapId].push(offerTokens[i]);

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < requestLength; ) {
            getRequestTokens[_currentSwapId].push(requestTokens[i]);

            unchecked {
                ++i;
            }
        }

        Swap memory newSwap = Swap(
            _currentSwapId,
            recipient,
            uint64(block.timestamp),
            uint24(allotedTime),
            SwapStatus.ACTIVE
        );

        getSwapIndex[_currentSwapId] = getSwaps[msg.sender].length;
        getSwaps[msg.sender].push(newSwap);

        emit SwapCreated(_currentSwapId, msg.sender, recipient);

        _currentSwapId++;
    }

    /// @notice Accepts an existing swap.
    /// @param id The id of the swap to accept.
    /// @param sender The address of the user that sent the swap request
    function acceptSwap(uint256 id, address sender) external {
        uint256 swapIndex = getSwapIndex[id];
        Swap memory swap = getSwaps[sender][swapIndex];

        if (swap.status == SwapStatus.INACTIVE) revert InactiveSwap();
        if (swap.status == SwapStatus.COMPLETE) revert AlreadyCompleted();
        if (swap.recipient != msg.sender) revert InvalidReceipient();
        if (block.timestamp > swap.createdAt + swap.allotedTime)
            revert InactiveSwap();

        getSwaps[sender][swapIndex].status = SwapStatus.COMPLETE;

        _swapTokens(getOfferTokens[swap.id], getRequestTokens[swap.id], sender);

        emit SwapAccepted(id, sender, msg.sender);
    }

    function _swapTokens(
        Token[] memory offerTokens,
        Token[] memory requestTokens,
        address to
    ) internal {
        for (uint256 i; i < offerTokens.length; ) {
            uint256 offerTokenLength = offerTokens[i].tokenIds.length;
            for (uint256 j; j < offerTokenLength; ) {
                if (
                    IERC165(offerTokens[i].contractAddress).supportsInterface(
                        0x80ac58cd
                    )
                ) {
                    IERC721(offerTokens[i].contractAddress).transferFrom(
                        msg.sender,
                        to,
                        offerTokens[i].tokenIds[j]
                    );
                } else if (
                    IERC165(offerTokens[i].contractAddress).supportsInterface(
                        0xd9b67a26
                    )
                ) {
                    IERC1155(offerTokens[i].contractAddress).safeTransferFrom(
                        msg.sender,
                        to,
                        offerTokens[i].tokenIds[j],
                        offerTokens[i].tokenQuantities[j],
                        ""
                    );
                } else if (
                    IERC165(offerTokens[i].contractAddress).supportsInterface(
                        0x36372b07
                    )
                ) {
                    IERC721(offerTokens[i].contractAddress).transferFrom(
                        msg.sender,
                        to,
                        offerTokens[i].tokenQuantities[0]
                    );
                } else {
                    revert NoncompliantTokens();
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < requestTokens.length; ) {
            uint256 offerTokenLength = requestTokens[i].tokenIds.length;
            for (uint256 j; j < offerTokenLength; ) {
                if (
                    IERC165(requestTokens[i].contractAddress).supportsInterface(
                        0x80ac58cd
                    )
                ) {
                    IERC721(requestTokens[i].contractAddress).transferFrom(
                        to,
                        msg.sender,
                        requestTokens[i].tokenIds[j]
                    );
                } else if (
                    IERC165(requestTokens[i].contractAddress).supportsInterface(
                        0xd9b67a26
                    )
                ) {
                    IERC1155(requestTokens[i].contractAddress).safeTransferFrom(
                            to,
                            msg.sender,
                            requestTokens[i].tokenIds[j],
                            requestTokens[i].tokenQuantities[j],
                            ""
                        );
                } else if (
                    IERC165(offerTokens[i].contractAddress).supportsInterface(
                        0x36372b07
                    )
                ) {
                    IERC721(offerTokens[i].contractAddress).transferFrom(
                        to,
                        msg.sender,
                        requestTokens[i].tokenQuantities[0]
                    );
                } else {
                    revert NoncompliantTokens();
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Gets the details of a single existing Swap.
    function getSwapSingle(uint256 id, address offerer)
        external
        view
        returns (Swap memory singleSwap)
    {
        singleSwap = getSwaps[offerer][getSwapIndex[id]];
    }

    /// @dev Function provided since Solidity converts public array to index getters.
    function getSwapOffer(uint256 id) external view returns (Token[] memory) {
        return getOfferTokens[id];
    }

    /// @dev Function provided since Solidity converts public array to index getters.
    function getSwapRequest(uint256 id) external view returns (Token[] memory) {
        return getRequestTokens[id];
    }

    /// @notice Gets all details of outgoing Swaps.
    /// @param user The user to get Swaps for.
    /// @dev Function provided since Solidity converts public array to index getters.
    function getSwapsOutgoing(address user)
        external
        view
        returns (Swap[] memory outgoingSwaps)
    {
        outgoingSwaps = getSwaps[user];
    }

    /// @notice Extends existing swap alloted time
    /// @param allotedTime Amount of time to increase swap alloted time for
    function extendAllotedTime(uint256 id, uint24 allotedTime) external {
        Swap storage swap = getSwaps[msg.sender][getSwapIndex[id]];

        if (swap.status == SwapStatus.INACTIVE) revert InactiveSwap();

        swap.allotedTime = swap.allotedTime + allotedTime;
    }

    /// @notice Manually deletes existing swap.
    function cancelSwap(uint256 id) external {
        Swap storage swap = getSwaps[msg.sender][getSwapIndex[id]];

        if (swap.status == SwapStatus.INACTIVE) revert InvalidInput();

        swap.status = SwapStatus.INACTIVE;

        emit SwapCancelled(id, msg.sender, swap.recipient);
    }
}
