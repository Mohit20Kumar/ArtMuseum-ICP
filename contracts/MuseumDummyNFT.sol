//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MuseumDummyNFT is ERC721URIStorage {
    address payable owner;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listPrice = 0.01 ether;

    constructor() ERC721("MuseumDummyNFT", "MDNFT") {
        owner = payable(msg.sender);
    }

    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    // creates a reverse mapping because we need to get the metadata from the token id
    mapping(uint256 => ListedToken) private idToListedToken;

    // not so important but we might need it later cauz smart contracts are immutable!!
    function updateListingPrice(uint256 _listPrice) public payable {
        require(
            owner == msg.sender,
            "Only Owner can UPDATE THE LISTING PRICE!!"
        );

        listPrice = _listPrice;
    }

    // important cauz we need to fetch this everytime we are listing our NFT/ART.
    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    // memory ==> uses a temporary location to store the stuff ---> uses less gas
    // storage ==> uses a more permanent location for storing ---> ends up taking tooo much gas and is costly and adds up to time of the transaction.

    // gives us the latest token data of the most recent token which was listed. very imp.
    function getLatestIdToListedToken()
        public
        view
        returns (ListedToken memory)
    {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    // returns the token data for a particular tokenID which can be showed in the front end which is very useful
    function getListedForTokenId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    // returns the current token ID
    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    // Creates the token for the NFT/ART and sends the tokenID to the createListedToken function for further process.
    function createToken(
        string memory tokenURI,
        uint256 price
    ) public payable returns (uint) {
        require(msg.value == listPrice, "Amount Not Suffient!");
        require(msg.value > 0, "Make Sure the Price isn't negative");

        _tokenIds.increment();

        uint256 currentTokenId = _tokenIds.current();
        _safeMint(msg.sender, currentTokenId);

        _setTokenURI(currentTokenId, tokenURI);

        createListedToken(currentTokenId, price);

        return currentTokenId;
    }

    // this function actually creates the obj of the art, and then it transfers the token to the contract address,
    // so now the contract is the owner of this NFT/ART, that way it is easy to sell the Art.(it is the right way tooo)
    function createListedToken(uint256 tokenId, uint256 price) private {
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        _transfer(msg.sender, address(this), tokenId);
    }

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current(); //gets the count of total nfts
        ListedToken[] memory tokens = new ListedToken[](nftCount); //creates an array from struct ListedToken with nftCount Size.

        uint currentIndex = 0;

        for (uint i = 0; i < nftCount; i++) {
            uint currentId = i + 1;

            // the obj with currentID get stored in currentItem (help from mapping idToListedToken).
            ListedToken storage currentItem = idToListedToken[currentId];

            // setting the array tokens particular id equal to current item.
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }

        return tokens;
    }

    // returns only my NFT/ART
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function executeSale(uint256 tokenId) public payable {
        uint price = idToListedToken[tokenId].price;
        address seller = idToListedToken[tokenId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].seller = payable(msg.sender);
        _itemsSold.increment();

        //Actually transfer the token to the new owner
        _transfer(address(this), msg.sender, tokenId);
        //approve the marketplace to sell NFTs on your behalf
        approve(address(this), tokenId);

        //Transfer the listing fee to the marketplace creator
        payable(owner).transfer(listPrice);
        //Transfer the proceeds from the sale to the seller of the NFT
        payable(seller).transfer(msg.value);
    }
}
