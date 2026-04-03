// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract MarketplaceFacetTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    ERC721Facet erc721Facet;
    ERC20Facet erc20Facet;
    MarketplaceFacet marketplaceFacet;
    
    address seller = address(0x1);
    address buyer = address(0x2);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        erc721Facet = new ERC721Facet();
        erc20Facet = new ERC20Facet();
        marketplaceFacet = new MarketplaceFacet();

        FacetCut[] memory cut = new FacetCut[](3);
        cut[0] = FacetCut(address(erc721Facet), FacetCutAction.Add, generateSelectors("ERC721Facet"));
        cut[1] = FacetCut(address(erc20Facet), FacetCutAction.Add, generateSelectors("ERC20Facet"));
        cut[2] = FacetCut(address(marketplaceFacet), FacetCutAction.Add, generateSelectors("MarketplaceFacet"));

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
    }

    function testListingAndBuying() public {
        ERC721Facet(address(diamond)).mint(seller, 1);
        ERC20Facet(address(diamond)).mintERC20(buyer, 100);
        
        vm.prank(seller);
        MarketplaceFacet(address(diamond)).listNFT(1, 100);

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), address(diamond));

        vm.prank(buyer);
        MarketplaceFacet(address(diamond)).buyNFT(1);

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), buyer);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(seller), 100);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(buyer), 0);
    }

    function testCancelListing() public {
        ERC721Facet(address(diamond)).mint(seller, 1);
        
        vm.prank(seller);
        MarketplaceFacet(address(diamond)).listNFT(1, 100);

        vm.prank(seller);
        MarketplaceFacet(address(diamond)).cancelListing(1);

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), seller);
    }

    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
