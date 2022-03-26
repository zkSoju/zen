// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.11;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);
}
