// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from 'forge-std/Script.sol';
import {PyeRouterV1} from '../src/PyeRouterV1.1.sol';
import {UpgradeableBeacon} from 'openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {StakeWiseAdapter} from '../src/adapters/StakeWise/StakeWiseAdapter.sol';

contract SystemDeploy is Script {
    address public constant SW_CHORUS_ONE_HOLESKY_VAULT = 0xd68AF28AeE9536144d4B9B6C0904CAf7E794B3D3;
    address public constant SW_CHORUS_ONE_MEV_HOLESKY_VAULT = 0x95D0Db03d59658E1Af0D977ECFE142f178930AC5;
    address public constant SW_FIGMENT_HOLESKY_VAULT = 0xA93da7468EE68b62472c7773b1c26FAcB1BC2c7f;
    address public constant SW_FIGMENT_HOLESKY_VAULT_V2 = 0x6E2F36e470b834C293808EE690fFF577A7A5b85C;
    address public constant SW_POOL_HOLESKY_VAULT = 0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4;
    address public constant SW_KEEPER_HOLESKY_RWRDS = 0xB580799Bf7d62721D1a523f0FDF2f5Ed7BA4e259;
    uint96 public constant MINT_FEE = 1000;
    uint96 public constant REDEMPTION_FEES = 1000;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PK');
        vm.startBroadcast(deployerPrivateKey);
        _deploy();
        vm.stopBroadcast();
    }

    function _deploy() internal {
        StakeWiseAdapter adapter = new StakeWiseAdapter('FigmentVault', SW_KEEPER_HOLESKY_RWRDS);
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(adapter), msg.sender);

        address[] memory validatorVaults = new address[](4);
        validatorVaults[0] = address(SW_CHORUS_ONE_HOLESKY_VAULT);
        validatorVaults[1] = address(SW_CHORUS_ONE_MEV_HOLESKY_VAULT);
        validatorVaults[2] = address(SW_FIGMENT_HOLESKY_VAULT);
        validatorVaults[3] = address(SW_POOL_HOLESKY_VAULT);

        PyeRouterV1 router = new PyeRouterV1(msg.sender, address(beacon), MINT_FEE, REDEMPTION_FEES, validatorVaults);
    }
}
