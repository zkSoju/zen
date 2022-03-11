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

    event SwapCreated(address indexed user, ZenSwap);

    event SwapAccepted(address indexed user, ZenSwap);

    event SwapUpdated(address indexed user, ZenSwap);

    event SwapCanceled(address indexed user, ZenSwap);

    event RequesterAdded(ZenSwap);

    /// @notice Azuki contract on mainnet
    IERC721 private immutable azuki;

    /// @notice BOBU contract on mainnet
    IERC1155 private immutable bobu;

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

    constructor(IERC721 _azuki, IERC1155 _bobu) {
        azuki = _azuki;
        bobu = _bobu;
    }

    /// @notice Creates a new swap.
    /// @param offerTokens721 ERC721 Token IDs offered by the offering party (caller).
    /// @param offerTokens1155 ERC1155 quantity of Bobu Token ID #1
    /// @param counterParty Opposing party the swap is initiated with.
    /// @param counterTokens721 ERC721 Token IDs requested from the counter party.
    /// @param counterTokens1155 ERC1155 quantity of Bobu Token ID #1 request from the counter party.
    /// @param allotedTime Time allocated for the swap, until it expires and becomes invalid.
    function createSwap(
        uint256[] calldata offerTokens721,
        uint256 offerTokens1155,
        address counterParty,
        uint256[] calldata counterTokens721,
        uint256 counterTokens1155,
        uint32 allotedTime
    ) external {
        if (offerTokens721.length == 0 && counterTokens721.length == 0)
            revert InvalidAction();
        if (allotedTime == 0) revert InvalidAction();
        if (allotedTime >= 365 days) revert InvalidAction();
        if (counterParty == address(0)) revert InvalidAction();
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

        /// Check if swap being pair already exists
        if (activeSwaps[msg.sender].counterParty != address(0)) {
            incomingRequesters[counterParty].push(msg.sender);
        }

        emit SwapCreated(msg.sender, swap);
    }

    /// @notice Accepts an existing swap.
    /// @param offerer Address of the offering party that initiated the swap
    function acceptSwap(address offerer) external {
        ZenSwap memory swap = activeSwaps[offerer];

        if (swap.counterParty != msg.sender) revert NonexistentTrade();
        if (block.timestamp > swap.createdAt + swap.allotedTime)
            revert TimeExpired();

        delete activeSwaps[offerer];

        _swapERC721(swap, offerer);
        _swapERC1155(swap, offerer);

        _removeRequester(msg.sender);

        emit SwapAccepted(msg.sender, swap);
    }

    function _removeRequester(address requester) internal {
        uint256 index = indexOfRequester[msg.sender][requester];

        uint256 length = incomingRequesters[requester].length;
        incomingRequesters[requester][index] = incomingRequesters[requester][
            length - 1
        ];
        incomingRequesters[requester].pop();
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
            azuki.transferFrom(offerer, msg.sender, offerTokens721[i]);

            unchecked {
                i++;
            }
        }

        for (uint256 i; i < counterLength721; ) {
            azuki.transferFrom(msg.sender, offerer, counterTokens721[i]);

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
            bobu.safeTransferFrom(
                offerer,
                msg.sender,
                1,
                offererQuantity1155,
                ""
            );
        }

        if (counterQuantity1155 != 0) {
            bobu.safeTransferFrom(
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
        return bobu.balanceOf(owner, 1) >= tokenQuantity;
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

    /// @notice Extends existing swap alloted time
    /// @param allotedTime Amount of time to increase swap alloted time for
    function extendAllotedTime(uint32 allotedTime) external {
        ZenSwap storage swap = activeSwaps[msg.sender];

        if (swap.counterParty == address(0)) revert InvalidAction();

        swap.allotedTime = swap.allotedTime + allotedTime;

        emit SwapUpdated(msg.sender, swap);
    }

    /// @notice Manually deletes existing swap.
    function cancelSwap() external {
        ZenSwap memory swap = activeSwaps[msg.sender];

        if (swap.counterParty == address(0)) revert InvalidAction();

        delete activeSwaps[msg.sender];

        emit SwapCanceled(msg.sender, activeSwaps[msg.sender]);
    }
}
