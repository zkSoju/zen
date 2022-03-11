pragma solidity 0.8.11;

import "./ERC721A.sol";

contract Azuki is ERC721A {
    string private _baseTokenURI =
        "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/";

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function mint() external {
        _safeMint(msg.sender, 1);
    }
}
