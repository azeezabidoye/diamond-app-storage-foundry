// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "../libraries/LibAppStorage.sol";

contract ERC20Facet {
    AppStorage internal s;

    event TransferERC20(address indexed from, address indexed to, uint256 value);
    event ApprovalERC20(address indexed owner, address indexed spender, uint256 value);

    function erc20Name() external view returns (string memory) {
        return s.erc20Name;
    }

    function erc20Symbol() external view returns (string memory) {
        return s.erc20Symbol;
    }

    function totalSupply() external view returns (uint256) {
        return s.erc20TotalSupply;
    }

    function erc20BalanceOf(address account) external view returns (uint256) {
        return s.erc20Balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return s.erc20Allowances[owner][spender];
    }

    function transferERC20(address to, uint256 amount) external returns (bool) {
        _transferERC20(msg.sender, to, amount);
        return true;
    }

    function approveERC20(address spender, uint256 amount) external returns (bool) {
        _approveERC20(msg.sender, spender, amount);
        return true;
    }

    function transferFromERC20(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowanceERC20(from, msg.sender, amount);
        _transferERC20(from, to, amount);
        return true;
    }

    function mintERC20(address to, uint256 amount) external {
        require(to != address(0), "ERC20: mint to the zero address");
        s.erc20TotalSupply += amount;
        s.erc20Balances[to] += amount;
        emit TransferERC20(address(0), to, amount);
    }

    function _transferERC20(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = s.erc20Balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            s.erc20Balances[from] = fromBalance - amount;
            s.erc20Balances[to] += amount;
        }

        emit TransferERC20(from, to, amount);
    }

    function _approveERC20(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        s.erc20Allowances[owner][spender] = amount;
        emit ApprovalERC20(owner, spender, amount);
    }

    function _spendAllowanceERC20(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = s.erc20Allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approveERC20(owner, spender, currentAllowance - amount);
            }
        }
    }
}
