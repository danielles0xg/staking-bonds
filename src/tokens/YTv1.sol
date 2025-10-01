// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract YTv1 is ERC20 {
    address private _admin;

    modifier onlyAdmin() {
        require(msg.sender == _admin, 'YTV1: caller is not the admin');
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _admin = msg.sender;
    }

    function mint(address to, uint256 amount) external onlyAdmin {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external onlyAdmin {
        _burn(to, amount);
    }
}
