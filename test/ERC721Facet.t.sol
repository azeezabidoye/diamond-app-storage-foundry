// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract ERC721FacetTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721Facet;
    
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721Facet = new ERC721Facet();

        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        cut[2] = FacetCut({
            facetAddress: address(erc721Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
    }

    function testDeployAndUpgrade() public {
        address[] memory addrs = DiamondLoupeFacet(address(diamond)).facetAddresses();
        assertEq(addrs.length, 4); // DiamondCutFacet, DiamondLoupeFacet, OwnershipFacet, ERC721Facet
    }

    function testMintingFromDiamond() public {
        ERC721Facet(address(diamond)).mint(user1, 1);
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 1);
        assertEq(ERC721Facet(address(diamond)).ownerOf(1), user1);
    }

    function testTransfer() public {
        ERC721Facet(address(diamond)).mint(user1, 1);
        
        vm.prank(user1);
        ERC721Facet(address(diamond)).transferFrom(user1, user2, 1);
        
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 0);
        assertEq(ERC721Facet(address(diamond)).balanceOf(user2), 1);
        assertEq(ERC721Facet(address(diamond)).ownerOf(1), user2);
    }
    
    function testApproval() public {
        ERC721Facet(address(diamond)).mint(user1, 1);
        
        vm.prank(user1);
        ERC721Facet(address(diamond)).approve(user2, 1);
        
        assertEq(ERC721Facet(address(diamond)).getApproved(1), user2);
        
        vm.prank(user2);
        ERC721Facet(address(diamond)).transferFrom(user1, address(0x3), 1);
        
        assertEq(ERC721Facet(address(diamond)).ownerOf(1), address(0x3));
    }
    
    function testApprovalForAll() public {
        ERC721Facet(address(diamond)).mint(user1, 1);
        ERC721Facet(address(diamond)).mint(user1, 2);
        
        vm.prank(user1);
        ERC721Facet(address(diamond)).setApprovalForAll(user2, true);
        
        assertEq(ERC721Facet(address(diamond)).isApprovedForAll(user1, user2), true);
        
        vm.prank(user2);
        ERC721Facet(address(diamond)).transferFrom(user1, address(0x3), 1);
        
        vm.prank(user2);
        ERC721Facet(address(diamond)).transferFrom(user1, address(0x3), 2);
        
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 0);
        assertEq(ERC721Facet(address(diamond)).balanceOf(address(0x3)), 2);
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
