// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./utils/Ownable.sol";
import "./ERC721A.sol";

contract BottleNft is ERC721A, Ownable {
    string public baseURI;
    uint96 public royaltyFeesInBips;
    address public royaltyAddress;

    mapping(address => bool) private whitelist;

    constructor(
        string memory _base,
        uint96 _fees,
        uint256 _maxBatchSize
    ) ERC721A("bottle", "btl", _maxBatchSize) {
        require(_fees <= 10000, "cannot exceed 10000");
        royaltyFeesInBips = _fees;
        royaltyAddress = msg.sender;
        baseURI = _base;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mint(address to, uint256 quantity) external {
        require(whitelist[msg.sender] || msg.sender == owner(), "NOT ALLOWED");
        _safeMint(to, quantity, "");
    }

    function allowMint(address _minter, bool status) external onlyOwner {
        whitelist[_minter] = status;
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256)
    {
        return (royaltyAddress, calculateRoyalty(_salePrice));
    }

    function setRoyaltyInfo(address _royaltyAddress, uint96 _royaltyFeesInBips)
        external
        onlyOwner
    {
        require(_royaltyFeesInBips <= 10000, "cannot exceed 10000");
        royaltyAddress = _royaltyAddress;
        royaltyFeesInBips = _royaltyFeesInBips;
    }

    function calculateRoyalty(uint256 _salePrice)
        public
        view
        returns (uint256)
    {
        return (_salePrice / 10000) * royaltyFeesInBips;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A)
        returns (bool)
    {
        return
            interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }
}
