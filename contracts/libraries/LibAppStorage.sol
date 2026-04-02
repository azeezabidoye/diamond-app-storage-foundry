// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct AppStorage {
    string name;
    string symbol;
    mapping(uint256 => address) owners;
    mapping(address => uint256) balances;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;
}
