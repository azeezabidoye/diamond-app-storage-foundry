// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/MultisigFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

contract FakeTarget {
    bool public changed = false;
    function change() external { changed = true; }
}

contract MultisigFacetTest is Test, IDiamondCut {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    MultisigFacet multisigFacet;
    FakeTarget target;
    
    address signer1 = address(0x1);
    address signer2 = address(0x2);

    function setUp() public {
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        multisigFacet = new MultisigFacet();
        target = new FakeTarget();

        FacetCut[] memory cut = new FacetCut[](1);
        cut[0] = FacetCut(address(multisigFacet), FacetCutAction.Add, generateSelectors("MultisigFacet"));

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        address[] memory signers = new address[](2);
        signers[0] = signer1;
        signers[1] = signer2;

        MultisigFacet(address(diamond)).setupMultisig(signers, 2);
    }

    function testProposalAndExecution() public {
        bytes memory data = abi.encodeWithSelector(FakeTarget.change.selector);
        
        vm.prank(signer1);
        uint256 pid = MultisigFacet(address(diamond)).submitProposal(address(target), data);
        
        vm.prank(signer2);
        MultisigFacet(address(diamond)).approveProposal(pid);

        vm.prank(signer1);
        MultisigFacet(address(diamond)).executeProposal(pid);

        assertTrue(target.changed());
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
