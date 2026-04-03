// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/BorrowingFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract BorrowingFacetTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    ERC721Facet erc721Facet;
    ERC20Facet erc20Facet;
    BorrowingFacet borrowingFacet;
    
    address user1 = address(0x1);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        erc721Facet = new ERC721Facet();
        erc20Facet = new ERC20Facet();
        borrowingFacet = new BorrowingFacet();

        FacetCut[] memory cut = new FacetCut[](3);
        cut[0] = FacetCut(address(erc721Facet), FacetCutAction.Add, generateSelectors("ERC721Facet"));
        cut[1] = FacetCut(address(erc20Facet), FacetCutAction.Add, generateSelectors("ERC20Facet"));
        cut[2] = FacetCut(address(borrowingFacet), FacetCutAction.Add, generateSelectors("BorrowingFacet"));

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
    }

    function testBorrowing() public {
        ERC721Facet(address(diamond)).mint(user1, 1);
        
        vm.startPrank(user1);
        BorrowingFacet(address(diamond)).borrow(1, 500 * 10**18);
        vm.stopPrank();

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), address(diamond));
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(user1), 500 * 10**18);
    }

    function testRepayment() public {
        ERC721Facet(address(diamond)).mint(user1, 1);
        
        vm.startPrank(user1);
        BorrowingFacet(address(diamond)).borrow(1, 100 * 10**18);
        
        // 5% interest
        // User needs 105 tokens to repay. Right now they have 100. Let's mint them 5 more.
        vm.stopPrank();
        ERC20Facet(address(diamond)).mintERC20(user1, 5 * 10**18);

        vm.startPrank(user1);
        BorrowingFacet(address(diamond)).repay(1);
        vm.stopPrank();

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), user1);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(user1), 0);
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
