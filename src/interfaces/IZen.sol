// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.11;

interface IZen {
    enum swapStatus {
        ACTIVE,
        COMPLETE,
        INACTIVE
    }

    struct ZenSwap {
        uint256 id;
        uint256[] offerTokens721;
        uint256 offerTokens1155;
        uint256[] requestTokens721;
        uint256 requestTokens1155;
        address requestFrom;
        uint64 createdAt;
        uint32 allotedTime;
        swapStatus status;
    }

    function getSwap(uint256 id, address offerer)
        external
        view
        returns (ZenSwap memory);
}
