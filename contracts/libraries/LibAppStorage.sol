// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Listing {
    address seller;
    uint256 price;
    bool active;
}

struct Loan {
    address borrower;
    uint256 amount;
    uint256 interestRate;
    uint256 duration;
    uint256 startTime;
    bool active;
}

struct Proposal {
    address target;
    bytes data;
    bool executed;
    uint256 approvalCount;
}

struct AppStorage {
    // ERC721 State
    string name;
    string symbol;
    mapping(uint256 => address) owners;
    mapping(address => uint256) balances;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;
    
    // Staking state
    mapping(uint256 => address) stakerAddress;
    mapping(uint256 => uint256) stakingStartTime;

    // ERC20 State
    string erc20Name;
    string erc20Symbol;
    uint256 erc20TotalSupply;
    mapping(address => uint256) erc20Balances;
    mapping(address => mapping(address => uint256)) erc20Allowances;

    // Marketplace State
    mapping(uint256 => Listing) listings;

    // Borrowing State
    mapping(uint256 => Loan) loans;

    // Multisig State
    uint256 requiredSignatures;
    mapping(address => bool) isSigner;
    mapping(uint256 => Proposal) proposals;
    mapping(uint256 => mapping(address => bool)) hasApproved;
    uint256 proposalCount;
}
