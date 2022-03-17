// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.11;

import {ERC1155} from "@solmate/tokens/ERC1155.sol";

contract MockBobu is ERC1155 {
    string private _baseTokenURI =
        "https://ikzttp.mypinata.cloud/ipfs/QmSJ9Q2zKgnx7dfjbhXHtQgbCEZoWX3rhnGZ3CnNX2wkfB/";

    address private owner;

    uint256 public currentSupply;

    constructor() ERC1155() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, 0, amount, "");
    }

    function uri(uint256 tokenId)
        public
        view
        override
        returns (string memory uri)
    {
        return string(abi.encodePacked(_baseTokenURI, tokenId));
    }
}
