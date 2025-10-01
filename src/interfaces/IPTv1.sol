// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

interface IPTv1 is IERC20 {
    function mint(address to, uint256 amount, bool isPtLock) external;
    function burn(address account, uint256 amount) external;
}
