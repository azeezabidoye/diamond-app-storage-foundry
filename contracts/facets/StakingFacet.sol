// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "../libraries/LibAppStorage.sol";

contract StakingFacet {
    AppStorage internal s;

    event Staked(address indexed user, uint256 tokenId, uint256 time);
    event Unstaked(address indexed user, uint256 tokenId, uint256 time);
    event RewardsClaimed(address indexed user, uint256 amount);

    uint256 public constant REWARD_RATE = 100 * 10**18; // 100 tokens per day
    uint256 public constant SECONDS_IN_DAY = 86400;

    function stake(uint256 _tokenId) external {
        require(s.owners[_tokenId] == msg.sender, "Staking: not token owner");
        require(s.stakerAddress[_tokenId] == address(0), "Staking: already staked");

        // Technically we lock the token by marking it as staked in state
        // but we'll also transfer it to address(this) to actually lock it in the Diamond.
        _transferInternal(msg.sender, address(this), _tokenId);

        s.stakerAddress[_tokenId] = msg.sender;
        s.stakingStartTime[_tokenId] = block.timestamp;

        emit Staked(msg.sender, _tokenId, block.timestamp);
    }

    function unstake(uint256 _tokenId) external {
        require(s.stakerAddress[_tokenId] == msg.sender, "Staking: not staker");

        uint256 reward = calculateReward(_tokenId);
        
        s.stakerAddress[_tokenId] = address(0);
        s.stakingStartTime[_tokenId] = 0;

        _transferInternal(address(this), msg.sender, _tokenId);

        if (reward > 0) {
            // Mint ERC20 rewards
            s.erc20TotalSupply += reward;
            s.erc20Balances[msg.sender] += reward;
            emit RewardsClaimed(msg.sender, reward);
        }

        emit Unstaked(msg.sender, _tokenId, block.timestamp);
    }

    function claimRewards(uint256 _tokenId) external {
        require(s.stakerAddress[_tokenId] == msg.sender, "Staking: not staker");
        
        uint256 reward = calculateReward(_tokenId);
        require(reward > 0, "Staking: no rewards");

        s.stakingStartTime[_tokenId] = block.timestamp;

        s.erc20TotalSupply += reward;
        s.erc20Balances[msg.sender] += reward;

        emit RewardsClaimed(msg.sender, reward);
    }

    function calculateReward(uint256 _tokenId) public view returns (uint256) {
        if (s.stakerAddress[_tokenId] == address(0)) return 0;
        uint256 stakedTime = block.timestamp - s.stakingStartTime[_tokenId];
        return (stakedTime * REWARD_RATE) / SECONDS_IN_DAY;
    }

    function _transferInternal(address _from, address _to, uint256 _tokenId) internal {
        // Clear approvals from the previous owner
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
    }
}
