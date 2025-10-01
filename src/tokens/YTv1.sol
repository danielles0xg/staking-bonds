// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract YTv1 is ERC20 {
    error OnlyBond();

    address private immutable _bond;

    modifier onlyBond() {
        if (msg.sender != _bond) revert OnlyBond();
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _bond = msg.sender;
    }

    function mint(address to, uint256 amount) external onlyBond {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external onlyBond {
        _burn(to, amount);
    }
}
