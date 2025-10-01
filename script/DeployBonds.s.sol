// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from 'forge-std/Script.sol';
import {PyeRouterV1} from '../src/PyeRouterV1.1.sol';
import {IPyeRouterV1} from '../src/interfaces/IPyeRouterV1.sol';
import {UpgradeableBeacon} from 'openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {StakeWiseAdapter} from '../src/adapters/StakeWise/StakeWiseAdapter.sol';

contract DeployBonds is Script {
    error BondCreationError(address validator, uint96 maturity);

    address public constant SW_CHORUS_ONE_HOLESKY_VAULT = 0xd68AF28AeE9536144d4B9B6C0904CAf7E794B3D3;
    address public constant SW_CHORUS_ONE_MEV_HOLESKY_VAULT = 0x95D0Db03d59658E1Af0D977ECFE142f178930AC5;
    address public constant SW_FIGMENT_HOLESKY_VAULT = 0xA93da7468EE68b62472c7773b1c26FAcB1BC2c7f;
    address public constant SW_POOL_HOLESKY_VAULT = 0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4;
    address public constant SW_KEEPER_HOLESKY_RWRDS = 0xB580799Bf7d62721D1a523f0FDF2f5Ed7BA4e259;

    uint96 public constant MINT_FEE = 1000;
    uint96 public constant REDEMPTION_FEES = 1000;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint('PK');
        vm.startBroadcast(deployerPrivateKey);

        // This is system deployments is only here for compile
        // but router and adapters are deployed before
        StakeWiseAdapter adapter = new StakeWiseAdapter('FigmentVault', SW_KEEPER_HOLESKY_RWRDS);
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(adapter), msg.sender);
        PyeRouterV1 router = new PyeRouterV1(msg.sender, address(beacon), MINT_FEE, REDEMPTION_FEES, _getValidators());

        _deployBonds(router, _getValidators(), _getMaturities());
        vm.stopBroadcast();
    }

    function _getValidators() internal returns (address[] memory) {
        address[] memory validators = new address[](5);
        validators[0] = SW_CHORUS_ONE_HOLESKY_VAULT;
        validators[1] = SW_CHORUS_ONE_MEV_HOLESKY_VAULT;
        validators[2] = SW_FIGMENT_HOLESKY_VAULT;
        validators[3] = SW_POOL_HOLESKY_VAULT;
        validators[4] = SW_KEEPER_HOLESKY_RWRDS;
        return validators;
    }

    function _getMaturities() internal returns (uint96[] memory) {
        uint96[] memory maturities = new uint96[](6);
        maturities[0] = 1727701200; //  Monday, September 30, 2024 1:00:00 PM GMT
        maturities[1] = 1735650000; //  Tuesday, December 31, 2024 1:00:00 PM GMT
        maturities[2] = 1743426000; //  Monday, March 31, 2025 1:00:00 PM GMT
        maturities[3] = 1751288400; //  Monday, June 30, 2025 1:00:00 PM GMT
        maturities[4] = 1759237200; //  Tuesday, September 30, 2025 1:00:00 PM
        maturities[5] = 1767186000; //  Wednesday, December 31, 2025 1:00:00 PM
        return maturities;
    }

    function _deployBonds(PyeRouterV1 router, address[] memory validators, uint96[] memory maturities) internal {
        uint256 maturitiesCount = maturities.length;
        for (uint256 i = 0; i < maturitiesCount;) {
            IPyeRouterV1.BondStorage memory bondStorage = router.createBond(validators[i], maturities[i]);
            if (bondStorage.maturity != maturities[i]) revert BondCreationError(validators[i], maturities[i]);
            unchecked {
                ++i;
            }
        }
    }
}
