// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Hook} from './ERC20Hook.sol';

contract PTv1 is ERC20Hook {
    error UnsupportedTransfer();

    constructor(string memory _name, string memory _symbol) ERC20Hook(_name, _symbol) {}

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (_isPtLocked[from]) revert UnsupportedTransfer();
    }

    function mint(address to, uint256 amount, bool isPtLock) external {
        _mint(to, amount, isPtLock);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}
