// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

interface IYTv1 is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address to, uint256 amount) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
