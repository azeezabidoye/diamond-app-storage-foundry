// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage, Listing} from "../libraries/LibAppStorage.sol";

contract MarketplaceFacet {
    AppStorage internal s;

    event ItemListed(address indexed seller, uint256 tokenId, uint256 price);
    event ItemSold(address indexed buyer, uint256 tokenId, uint256 price);
    event ItemCanceled(uint256 tokenId);

    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(s.owners[_tokenId] == msg.sender, "Marketplace: not token owner");
        require(_price > 0, "Marketplace: price must be > 0");
        require(!s.listings[_tokenId].active, "Marketplace: already listed");

        // Lock NFT inside contract
        _transferInternal(msg.sender, address(this), _tokenId);

        s.listings[_tokenId] = Listing({
            seller: msg.sender,
            price: _price,
            active: true
        });

        emit ItemListed(msg.sender, _tokenId, _price);
    }

    function buyNFT(uint256 _tokenId) external {
        Listing memory listing = s.listings[_tokenId];
        require(listing.active, "Marketplace: not listed");
        
        // Buyer must have ERC20 allowance or sufficient balance. 
        // Wait, AppStorage gives us direct access so we can just deduct directly if they have balance, 
        // normally we would transferFrom ERC20, but since both are on the same diamond, we do it directly.
        require(s.erc20Balances[msg.sender] >= listing.price, "Marketplace: insufficient ERC20 balance");

        // Execute Payment
        s.erc20Balances[msg.sender] -= listing.price;
        s.erc20Balances[listing.seller] += listing.price;

        // Unlock & Transfer NFT to buyer
        s.listings[_tokenId].active = false;
        _transferInternal(address(this), msg.sender, _tokenId);

        emit ItemSold(msg.sender, _tokenId, listing.price);
    }

    function cancelListing(uint256 _tokenId) external {
        Listing memory listing = s.listings[_tokenId];
        require(listing.active, "Marketplace: not listed");
        require(listing.seller == msg.sender, "Marketplace: not seller");

        s.listings[_tokenId].active = false;
        
        // Return NFT
        _transferInternal(address(this), msg.sender, _tokenId);

        emit ItemCanceled(_tokenId);
    }

    function _transferInternal(address _from, address _to, uint256 _tokenId) internal {
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
    }
}
