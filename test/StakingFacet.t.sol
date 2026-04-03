// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/StakingFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract StakingFacetTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721Facet;
    StakingFacet stakingFacet;

    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721Facet = new ERC721Facet();
        stakingFacet = new StakingFacet();

        FacetCut[] memory cut = new FacetCut[](4);

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

        cut[3] = FacetCut({
            facetAddress: address(stakingFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("StakingFacet")
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
    }

    function testDeployAndUpgradeStaking() public {
        address[] memory addrs = DiamondLoupeFacet(address(diamond))
            .facetAddresses();
        assertEq(addrs.length, 5); // DiamondCutFacet, DiamondLoupeFacet, OwnershipFacet, ERC721Facet, StakingFacet
    }

    function testStaking() public {
        ERC721Facet(address(diamond)).mint(user1, 1);

        vm.startPrank(user1);
        StakingFacet(address(diamond)).stake(1);
        vm.stopPrank();

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), address(diamond));
        assertEq(StakingFacet(address(diamond)).getStaker(1), user1);
        assertTrue(StakingFacet(address(diamond)).getStakingStartTime(1) > 0);
    }

    function testUnstaking() public {
        ERC721Facet(address(diamond)).mint(user1, 1);

        vm.startPrank(user1);
        StakingFacet(address(diamond)).stake(1);
        StakingFacet(address(diamond)).unstake(1);
        vm.stopPrank();

        assertEq(ERC721Facet(address(diamond)).ownerOf(1), user1);

        vm.expectRevert("StakingFacet: token not staked");
        StakingFacet(address(diamond)).getStaker(1);
    }

    function testOnlyOwnerCanStake() public {
        ERC721Facet(address(diamond)).mint(user2, 1);

        vm.startPrank(user1);
        vm.expectRevert("StakingFacet: caller is not token owner");
        StakingFacet(address(diamond)).stake(1);
        vm.stopPrank();
    }

    function testOnlyStakerCanUnstake() public {
        ERC721Facet(address(diamond)).mint(user1, 1);

        vm.prank(user1);
        StakingFacet(address(diamond)).stake(1);

        vm.prank(user2);
        vm.expectRevert("StakingFacet: caller is not staker");
        StakingFacet(address(diamond)).unstake(1);
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
