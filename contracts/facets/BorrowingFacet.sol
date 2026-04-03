// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage, Loan} from "../libraries/LibAppStorage.sol";

contract BorrowingFacet {
    AppStorage internal s;

    event Borrowed(address indexed user, uint256 tokenId, uint256 amount);
    event Repaid(address indexed user, uint256 tokenId);

    // Hardcoded simple metrics for brevity
    uint256 public constant MAX_LOAN_AMOUNT = 1000 * 10**18;
    uint256 public constant INTEREST_RATE = 5; // 5% flat fee

    function borrow(uint256 _tokenId, uint256 _amount) external {
        require(s.owners[_tokenId] == msg.sender, "Borrowing: not token owner");
        require(_amount <= MAX_LOAN_AMOUNT, "Borrowing: exceeds max amount");
        require(!s.loans[_tokenId].active, "Borrowing: active loan exists");

        // Lock NFT
        _transferInternal(msg.sender, address(this), _tokenId);

        // Create Loan
        s.loans[_tokenId] = Loan({
            borrower: msg.sender,
            amount: _amount,
            interestRate: INTEREST_RATE,
            duration: 30 days, // flat duration for demo
            startTime: block.timestamp,
            active: true
        });

        // Lend out ERC20 to user
        s.erc20TotalSupply += _amount;
        s.erc20Balances[msg.sender] += _amount;

        emit Borrowed(msg.sender, _tokenId, _amount);
    }

    function repay(uint256 _tokenId) external {
        Loan memory loan = s.loans[_tokenId];
        require(loan.active, "Borrowing: no active loan");
        require(loan.borrower == msg.sender, "Borrowing: not borrower");

        uint256 interestAmount = (loan.amount * loan.interestRate) / 100;
        uint256 totalRepayment = loan.amount + interestAmount;

        // Take ERC20 repayment from user
        require(s.erc20Balances[msg.sender] >= totalRepayment, "Borrowing: insufficient ERC20 balance");
        
        s.erc20Balances[msg.sender] -= totalRepayment;
        s.erc20TotalSupply -= totalRepayment; // Burn the tokens for simplicity

        // Unlock NFT
        s.loans[_tokenId].active = false;
        _transferInternal(address(this), msg.sender, _tokenId);

        emit Repaid(msg.sender, _tokenId);
    }

    function _transferInternal(address _from, address _to, uint256 _tokenId) internal {
        delete s.tokenApprovals[_tokenId];
        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;
    }
}
