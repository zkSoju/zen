// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.11;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

contract Azuki is ERC721, ERC721Enumerable {
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

    function getTokenIds(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 length = balanceOf(_owner);
        uint256[] memory tokensOfOwner = new uint256[](length);

        for (uint256 i; i < length; ) {
            tokensOfOwner[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return (tokensOfOwner);
    }
}
