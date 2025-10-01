// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Hook} from './ERC20Hook.sol';

contract PTv1 is ERC20Hook {
    error UnsupportedTransfer();
    error OnlyBond();

    address private immutable _bond;

    constructor(string memory _name, string memory _symbol) ERC20Hook(_name, _symbol) {
        _bond = msg.sender;
    }

    modifier onlyBond() {
        if (msg.sender != _bond) revert OnlyBond();
        _;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        if (_isPtLocked[from]) revert UnsupportedTransfer();
    }

    function mint(address to, uint256 amount, bool isPtLock) external onlyBond {
        _mint(to, amount, isPtLock);
    }

    function burn(address account, uint256 amount) public onlyBond {
        _burn(account, amount);
    }
}
