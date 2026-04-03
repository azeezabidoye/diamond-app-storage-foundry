// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract ERC20FacetTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20Facet;
    
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20Facet = new ERC20Facet();

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
            facetAddress: address(erc20Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC20Facet")
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
    }

    function testMintERC20() public {
        ERC20Facet(address(diamond)).mintERC20(user1, 1000);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(user1), 1000);
        assertEq(ERC20Facet(address(diamond)).totalSupply(), 1000);
    }

    function testTransferERC20() public {
        ERC20Facet(address(diamond)).mintERC20(user1, 1000);
        
        vm.prank(user1);
        ERC20Facet(address(diamond)).transferERC20(user2, 400);

        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(user1), 600);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(user2), 400);
    }

    function testApprovalAndTransferFrom() public {
        ERC20Facet(address(diamond)).mintERC20(user1, 1000);
        
        vm.prank(user1);
        ERC20Facet(address(diamond)).approveERC20(user2, 500);
        
        assertEq(ERC20Facet(address(diamond)).allowance(user1, user2), 500);

        vm.prank(user2);
        ERC20Facet(address(diamond)).transferFromERC20(user1, address(0x3), 200);

        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(user1), 800);
        assertEq(ERC20Facet(address(diamond)).erc20BalanceOf(address(0x3)), 200);
        assertEq(ERC20Facet(address(diamond)).allowance(user1, user2), 300);
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
