// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "../libraries/LibAppStorage.sol";

contract ERC721Facet {
    AppStorage internal s;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    function name() external view returns (string memory) {
        return s.name;
    }

    function symbol() external view returns (string memory) {
        return s.symbol;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        require(
            _owner != address(0),
            "ERC721: address zero is not a valid owner"
        );
        return s.balances[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function mint(address _to, uint256 _tokenId) external {
        require(_to != address(0), "ERC721: mint to the zero address");
        require(
            s.owners[_tokenId] == address(0),
            "ERC721: token already minted"
        );

        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;

        emit Transfer(address(0), _to, _tokenId);
    }

    function approve(address _approved, uint256 _tokenId) external {
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        require(_approved != owner, "ERC721: approval to current owner");

        require(
            msg.sender == owner || s.operatorApprovals[owner][msg.sender],
            "ERC721: approve caller is not owner nor approved for all"
        );

        s.tokenApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        require(s.owners[_tokenId] != address(0), "ERC721: invalid token ID");
        return s.tokenApprovals[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        require(msg.sender != _operator, "ERC721: approve to caller");
        s.operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {
        return s.operatorApprovals[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        address owner = s.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        require(owner == _from, "ERC721: transfer from incorrect owner");
        require(_to != address(0), "ERC721: transfer to the zero address");

        require(
            msg.sender == owner ||
                s.tokenApprovals[_tokenId] == msg.sender ||
                s.operatorApprovals[owner][msg.sender],
            "ERC721: caller is not token owner or approved"
        );

        // Clear approvals from the previous owner
        delete s.tokenApprovals[_tokenId];

        s.balances[_from] -= 1;
        s.balances[_to] += 1;
        s.owners[_tokenId] = _to;

        emit Transfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        transferFrom(_from, _to, _tokenId);
    }
}
