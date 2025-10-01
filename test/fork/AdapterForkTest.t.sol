// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console, console2, Vm} from 'forge-std/Test.sol';
import {IEthVault, IKeeperRewards} from '../../src/adapters/StakeWise/interfaces/IEthVault.sol';

contract AdapterForkTest is Test {
    IEthVault public vault;
    address public SW_HOLESKY_VAULT = 0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4;
    address public SW_HOLESKY_RWRDS = 0xB580799Bf7d62721D1a523f0FDF2f5Ed7BA4e259;

    string constant TESTNET = 'https://holesky.infura.io/v3/41da61585a3c420cb9067f9e5edb5d0c';

    function setUp() public {
        vault = IEthVault(SW_HOLESKY_VAULT);
        vm.createSelectFork(TESTNET);
        console.log('init time', vm.getBlockTimestamp());
    }

    function ethVaultFlow() public {
        // deposit 1 eth
        uint256 shares = vault.deposit{value: 1 ether}(address(this), address(0x0));
        assert(vault.convertToAssets(shares) == 1 ether);

        // warp 20 days
        vm.warp(vm.getBlockTimestamp() + 20 days);

        // enter exit queue
        console.log('enterExitQueue time', block.timestamp);
        uint256 ticket = vault.enterExitQueue(vault.getShares(address(this)), address(this));
        uint256 timestamp = vm.getBlockTimestamp();

        // mock keeeper
        bytes32[] memory proof = new bytes32[](6);
        proof[0] = 0x5b2b86cea4e64cf68b43877e45986ce6d89a812bc333e7f2c2c1179b2b5de19f;
        proof[1] = 0x60d6c52b4b156222c2d3553e257890ea92337cf21c6f8a147cf8a8653993baf1;
        proof[2] = 0x08dc67ba8a3f1f3a4a26af7579384382c30952263e1c56d1fbd0c4df9d29f1d7;
        proof[3] = 0x63f6049c4e5c297173c84be636263da10490731a0879f32a2ee768cc6a12734d;
        proof[4] = 0x44cbf41f6df899c2ec6d19862f40d3cd7e305dc56c9ce7eb04158cadd7f83974;
        proof[5] = 0xb9c45b1a9063b675bb3fa296d37851a4af900a0377bf7da1d86adc3e23f4d163;
        bytes32 root = IKeeperRewards(SW_HOLESKY_RWRDS).rewardsRoot();
        console2.logBytes32(root);

        vm.prank(address(vault));
        vault.updateState(IKeeperRewards.HarvestParams({rewardsRoot: root, reward: 34688051606162985825, unlockedMevReward: 438934671162985825, proof: proof}));

        // warp 20 days
        vm.warp(vm.getBlockTimestamp() + 20 days);

        // claim exited assets
        console.log('unstake time', vm.getBlockTimestamp());
        (uint256 newPositionTicket, uint256 claimedShares, uint256 claimedAssets) = vault.claimExitedAssets(ticket, timestamp, uint256(vault.getExitQueueIndex(ticket)));
    }
}
