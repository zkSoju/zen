// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import "@openzeppelin/interfaces/IERC165.sol";
import "@openzeppelin/interfaces/IERC20.sol";
import "@openzeppelin/interfaces/IERC721.sol";
import "@openzeppelin/interfaces/IERC1155.sol";

error InactiveSwap();
error InvalidInput();
error InvalidReceipient();
error AlreadyCompleted();
error NotAuthorized();
error NoncompliantTokens();

/// @title Zen (Red Bean Swap)
/// @author The Garden
contract Zen {
    /// >>>>>>>>>>>>>>>>>>>>>>>>>  METADATA   <<<<<<<<<<<<<<<<<<<<<<<<< ///

    uint256 private _currentSwapId;

    enum SwapStatus {
        ACTIVE,
        COMPLETE,
        INACTIVE
    }

    struct Token {
        address contractAddress;
        uint256[] tokenIds;
        uint256[] quantities;
    }

    /// @notice The packed struct of swap data.
    /// @param to The opposing party the swap is interacting with.
    /// @param createdAt The timestamp of swap creation.
    /// @param allotedTime The time allocated for the swap.
    /// @param status The status that determines the state of the swap.
    /// @dev The status of the swap becomes inactive when time expires.
    struct Swap {
        uint256 id;
        address to;
        uint64 createdAt;
        uint24 allotedTime;
        SwapStatus status;
    }

    struct IncomingData {
        uint256 id;
        address from;
    }

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
    /// @param to Opposing party the swap is initiated with.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    function createSwap(
        Token[] calldata offerTokens,
        Token[] calldata requestTokens,
        address to,
        uint256 allotedTime
    ) external {
        if (offerTokens.length == 0 && requestTokens.length == 0)
            revert InvalidInput();
        if (allotedTime == 0) revert InvalidInput();
        if (allotedTime >= 365 days) revert InvalidInput();
        if (to == address(0)) revert InvalidInput();
        if (!_checkCompliance(offerTokens, requestTokens))
            revert NoncompliantTokens();

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
            to,
            uint64(block.timestamp),
            uint24(allotedTime),
            SwapStatus.ACTIVE
        );

        getSwapIndex[_currentSwapId] = getSwaps[msg.sender].length;
        getSwaps[msg.sender].push(newSwap);

        _currentSwapId++;
    }

    /// @notice Accepts an existing swap.
    /// @param id The id of the swap to accept.
    /// @param offerer The address of the offering party that initiated the swap
    function acceptSwap(uint256 id, address offerer) external {
        uint256 swapIndex = getSwapIndex[id];
        Swap memory swap = getSwaps[offerer][swapIndex];

        if (swap.status == SwapStatus.INACTIVE) revert InactiveSwap();
        if (swap.status == SwapStatus.COMPLETE) revert AlreadyCompleted();
        if (swap.to != msg.sender) revert InvalidReceipient();
        if (block.timestamp > swap.createdAt + swap.allotedTime)
            revert InactiveSwap();

        getSwaps[offerer][swapIndex].status = SwapStatus.COMPLETE;

        _swapTokens(
            getOfferTokens[swap.id],
            getRequestTokens[swap.id],
            offerer
        );
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
                        offerTokens[i].quantities[j],
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
                        offerTokens[i].quantities[0]
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
                            requestTokens[i].quantities[j],
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
                        requestTokens[i].quantities[0]
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

    function _checkCompliance(Token[] memory offer, Token[] memory request)
        internal
        view
        returns (bool)
    {
        uint256 offerLength = offer.length;
        uint256 requestLength = request.length;
        for (uint256 i; i < offerLength; ) {
            if (!_supportsInterfaces(offer[i].contractAddress))
                revert NoncompliantTokens();
            unchecked {
                ++i;
            }
        }

        return true;
    }

    function _supportsInterfaces(address contractAddress)
        internal
        view
        returns (bool)
    {
        return
            IERC165(contractAddress).supportsInterface(0xd9b67a26) ||
            IERC165(contractAddress).supportsInterface(0x80ac58cd);
    }

    /// @notice Gets the details of a single existing Swap.
    function getSwapSingle(uint256 id, address offerer)
        external
        view
        returns (Swap memory)
    {
        return getSwaps[offerer][getSwapIndex[id]];
    }

    /// @notice Gets all details of outgoing Swaps.
    /// @param user The user to get Swaps for.
    /// @dev Function provided since Solidity converts public array to index getters.
    function getSwapsOutgoing(address user)
        external
        view
        returns (Swap[] memory)
    {
        return getSwaps[user];
    }

    /// @notice Gets all details of existing swaps.
    /// @param user The user to get incoming swaps for.
    // function getSwapsIncoming(address user)
    //     external
    //     view
    //     returns (Swap[] memory)
    // {
    //     uint256 length = getIncomingData[user].length;
    //     Swap[] memory swaps = new Swap[](length);

    //     for (uint256 i; i < length; i++) {
    //         IncomingData memory data = getIncomingData[user][i];
    //         swaps[i] = getSwaps[data.from][getSwapIndex[data.id]];
    //     }

    //     return swaps;
    // }

    /// @notice Extends existing swap alloted time
    /// @param allotedTime Amount of time to increase swap alloted time for
    function extendAllotedTime(uint256 id, uint24 allotedTime) external {
        Swap storage swap = getSwaps[msg.sender][getSwapIndex[id]];

        if (swap.status == SwapStatus.INACTIVE) revert InvalidInput();

        swap.allotedTime = swap.allotedTime + allotedTime;
    }

    /// @notice Manually deletes existing swap.
    function cancelSwap(uint256 id) external {
        Swap storage swap = getSwaps[msg.sender][getSwapIndex[id]];

        if (swap.status == SwapStatus.INACTIVE) revert InvalidInput();

        swap.status = SwapStatus.INACTIVE;
    }
}
