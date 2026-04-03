// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage, Proposal} from "../libraries/LibAppStorage.sol";

contract MultisigFacet {
    AppStorage internal s;

    event ProposalSubmitted(uint256 indexed proposalId, address target);
    event ProposalApproved(uint256 indexed proposalId, address approver);
    event ProposalExecuted(uint256 indexed proposalId);
    event SignerAdded(address signer);

    modifier onlySigner() {
        require(s.isSigner[msg.sender], "Multisig: not a signer");
        _;
    }

    // Usually called upon diamond initialization, adding here for first-time setup ability
    function setupMultisig(address[] calldata _signers, uint256 _requiredSignatures) external {
        require(s.requiredSignatures == 0, "Multisig: already setup");
        require(_signers.length >= _requiredSignatures, "Multisig: invalid req sigs");
        
        for (uint i = 0; i < _signers.length; i++) {
            s.isSigner[_signers[i]] = true;
            emit SignerAdded(_signers[i]);
        }
        s.requiredSignatures = _requiredSignatures;
    }

    function submitProposal(address _target, bytes calldata _data) external onlySigner returns (uint256) {
        uint256 pid = s.proposalCount++;
        s.proposals[pid] = Proposal({
            target: _target,
            data: _data,
            executed: false,
            approvalCount: 0
        });

        // Auto approve by submitter
        _approve(pid, msg.sender);
        
        emit ProposalSubmitted(pid, _target);
        return pid;
    }

    function approveProposal(uint256 _proposalId) external onlySigner {
        _approve(_proposalId, msg.sender);
    }

    function _approve(uint256 _proposalId, address _signer) internal {
        require(_proposalId < s.proposalCount, "Multisig: invalid proposal");
        require(!s.proposals[_proposalId].executed, "Multisig: already executed");
        require(!s.hasApproved[_proposalId][_signer], "Multisig: already approved");

        s.hasApproved[_proposalId][_signer] = true;
        s.proposals[_proposalId].approvalCount++;

        emit ProposalApproved(_proposalId, _signer);
    }

    function executeProposal(uint256 _proposalId) external onlySigner {
        Proposal storage p = s.proposals[_proposalId];
        require(!p.executed, "Multisig: already executed");
        require(p.approvalCount >= s.requiredSignatures, "Multisig: threshold not met");

        p.executed = true;

        (bool success, ) = p.target.call(p.data);
        require(success, "Multisig: execution failed");

        emit ProposalExecuted(_proposalId);
    }
}
