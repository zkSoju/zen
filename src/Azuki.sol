// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.11;

import "@openzeppelin/token/ERC721/ERC721.sol";

contract Azuki is ERC721 {
    string private _baseTokenURI =
        "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/";

    address private owner;

    uint256 public currentSupply;

    constructor() ERC721("Azuki", "AZUKI") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function mint() external {
        _safeMint(msg.sender, currentSupply);
        currentSupply += 1;
    }
}
