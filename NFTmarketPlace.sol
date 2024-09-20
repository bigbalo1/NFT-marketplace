// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;
    uint256 public listingFee = 0.01 ether;
    
    struct Listing {
        address seller;
        uint256 price;
        bool isListed;
    }
    
    // tokenId => Listing
    mapping(uint256 => Listing) public listings;

    event NFTMinted(address indexed owner, uint256 indexed tokenId, string tokenURI);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    constructor() ERC721("NFTMarketplace", "NFTM") {}

    // Minting function only accessible by the contract owner (marketplace admin)
    function mintNFT(address recipient, string memory tokenURI) external onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId;
        nextTokenId++;

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit NFTMinted(recipient, tokenId, tokenURI);
        return tokenId;
    }

    // Function for users to list their NFTs for sale
    function listNFT(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        require(price > 0, "Price must be greater than zero");

        listings[tokenId] = Listing(msg.sender, price, true);

        emit NFTListed(tokenId, price);
    }

    // Function to remove a listed NFT from sale
    function delistNFT(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        require(listings[tokenId].isListed, "NFT is not listed");

        listings[tokenId].isListed = false;
    }

    // Function to buy a listed NFT
    function buyNFT(uint256 tokenId) external payable {
        Listing memory listing = listings[tokenId];
        require(listing.isListed, "NFT is not listed for sale");
        require(msg.value == listing.price, "Incorrect price");

        address seller = listing.seller;

        // Transfer NFT from seller to buyer
        _transfer(seller, msg.sender, tokenId);

        // Send payment to seller
        payable(seller).transfer(msg.value);

        // Mark NFT as sold (delist)
        listings[tokenId].isListed = false;

        emit NFTSold(tokenId, seller, msg.sender, listing.price);
    }

    // Owner can withdraw accumulated listing fees
    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Set listing fee by the owner
    function setListingFee(uint256 _fee) external onlyOwner {
        listingFee = _fee;
    }

    // Modifier to ensure function callers pay listing fees
    modifier payListingFee() {
        require(msg.value == listingFee, "Listing fee required");
        _;
    }
}
