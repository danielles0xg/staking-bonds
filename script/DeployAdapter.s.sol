// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from 'forge-std/Script.sol';
import {StakeWiseAdapter} from '../src/adapters/StakeWise/StakeWiseAdapter.sol';

/**
 * forge script script/DeployAdapter.s.sol:DeployAdapter --rpc-url $HOLESKY_URL  --chain holesky  --broadcast --verify
 * Lib linking  --libraries src/libs/ExpiryUtils.sol:ExpiryUtils:0xbba21b888047015b15cbd2ab574279667cb94c3d
 * forge create src/adapters/StakeWise/StakeWiseAdapter.sol:StakeWiseAdapter --constructor-args 0xA93da7468EE68b62472c7773b1c26FAcB1BC2c7f --rpc-url $HOLESKY_URL --chain holesky --verify  --private-key $PK --libraries src/libs/ExpiryUtils.sol:ExpiryUtils:0xbba21b888047015b15cbd2ab574279667cb94c3d
 */
contract DeployAdapter is Script {
    address public constant SW_FIGMENT_HOLESKY_VAULT = 0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4;
    address public constant SW_KEEPER_HOLESKY_RWRDS = 0xA93da7468EE68b62472c7773b1c26FAcB1BC2c7f;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PK');
        vm.startBroadcast(deployerPrivateKey);
        _deploy();
        vm.stopBroadcast();
    }

    function _deploy() internal returns (address _adapter) {
        StakeWiseAdapter adapter = new StakeWiseAdapter('FigmentVault', SW_KEEPER_HOLESKY_RWRDS);
        adapter.initialize(SW_FIGMENT_HOLESKY_VAULT, uint96(block.timestamp + 1 days));
        _adapter = payable(address(adapter));
    }
}
