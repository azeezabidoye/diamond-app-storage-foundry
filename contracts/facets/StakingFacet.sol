// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "../libraries/LibAppStorage.sol";

contract StakingFacet {
    AppStorage internal s;

    event Staked(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event Unstaked(address indexed user, uint256 indexed tokenId, uint256 timestamp);

    function stake(uint256 _tokenId) external {
        address owner = s.owners[_tokenId];
        require(owner == msg.sender, "StakingFacet: caller is not token owner");
        
        // Transfer to address(this) to lock the token
        // Clear approvals from the previous owner
        delete s.tokenApprovals[_tokenId];

        s.balances[msg.sender] -= 1;
        s.balances[address(this)] += 1;
        s.owners[_tokenId] = address(this);

        // Update Staking state
        s.stakerAddress[_tokenId] = msg.sender;
        s.stakingStartTime[_tokenId] = block.timestamp;

        emit Staked(msg.sender, _tokenId, block.timestamp);
    }

    function unstake(uint256 _tokenId) external {
        require(s.stakerAddress[_tokenId] == msg.sender, "StakingFacet: caller is not staker");

        // Update Staking state
        delete s.stakerAddress[_tokenId];
        delete s.stakingStartTime[_tokenId];

        // Transfer back to the user
        s.balances[address(this)] -= 1;
        s.balances[msg.sender] += 1;
        s.owners[_tokenId] = msg.sender;

        emit Unstaked(msg.sender, _tokenId, block.timestamp);
    }

    function getStaker(uint256 _tokenId) external view returns (address) {
        address staker = s.stakerAddress[_tokenId];
        require(staker != address(0), "StakingFacet: token not staked");
        return staker;
    }

    function getStakingStartTime(uint256 _tokenId) external view returns (uint256) {
        require(s.stakerAddress[_tokenId] != address(0), "StakingFacet: token not staked");
        return s.stakingStartTime[_tokenId];
    }
}
