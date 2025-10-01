// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console, Vm} from 'forge-std/Test.sol';
import {StakeWiseAdapter} from '../../src/adapters/StakeWise/StakeWiseAdapter.sol';
import {BeaconProxy} from 'openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol';
import {BaseTest} from './BaseTest.t.sol';
import {UpgradeableBeacon} from 'openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol';
import {IBond} from '../../src/interfaces/IBond.sol';
import {IPTv1} from '../../src/interfaces/IPTv1.sol';
import {IYTv1} from '../../src/interfaces/IYTv1.sol';
import {WadRayMath} from '../../src/libs/WadRayMath.sol';
import {PyeRouterV1} from '../../src/PyeRouterV1.1.sol';
import {KeeperMock, SwEthVaulMock} from '../../src/mock/SwEthVaulMock.sol';

contract StakeWiseAdapterTest is BaseTest {
    using WadRayMath for uint256;

    PyeRouterV1 public router;
    StakeWiseAdapter public adapter;
    SwEthVaulMock public swEthVault;
    KeeperMock public keeper;
    IYTv1 public yt;
    IPTv1 public pt;
    address public beacon;
    string public constant STAKE_VAULT_NAME = 'FigmentTestVault';
    uint96 public constant MINT_FEE = 1000;
    uint96 public constant REDEMPTION_FEE = 1000;

    function setUp() public {
        uint256 MOCK_VALIDATOR_APY = 500; // 5% bp
        swEthVault = new SwEthVaulMock{value: 100 ether}(MOCK_VALIDATOR_APY);
        keeper = new KeeperMock(address(swEthVault));
        adapter = new StakeWiseAdapter(STAKE_VAULT_NAME, address(keeper));
        beacon = address(new UpgradeableBeacon(address(adapter), msg.sender));
        address[] memory validatorVaults = new address[](1);
        validatorVaults[0] = address(swEthVault);
        router = new PyeRouterV1(msg.sender, beacon, MINT_FEE, REDEMPTION_FEE, validatorVaults);
    }

    function _initBond(address _validatorVault, uint96 _maturity) internal returns (address _bond) {
        vm.prank(address(router));
        _bond = address(
            new BeaconProxy(
                beacon, // beacon contract of specific provider
                abi.encodeWithSignature('initialize(address,uint96)', _validatorVault, _maturity)
            )
        );
        vm.stopPrank();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   TEST INITIALIER                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_initialize() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.vault(), address(swEthVault));
        assertEq(bond.rewardsVault(), address(keeper));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   TEST SW STAKING FUNCTIONS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_adapter_deposit(uint256 _amount, bool isPtLocked, bytes memory _data) external {
        // bond params
        uint96 one_year_maturity = uint96(block.timestamp + ONE_YEAR_SECONDS);
        bool isPtLocked = true;
        uint256 depositAmount = 1 ether;

        // create user, bond
        IBond bond = IBond(_initBond(address(swEthVault), one_year_maturity)); // 6 months bond
        address alice = _createUser('test_deposit_user', depositAmount);

        // Alice deposits 6 months after bond creation
        vm.warp(block.timestamp + ONE_YEAR_SECONDS / 2);

        // user deposit
        vm.startPrank(alice);
        uint256 expectedShares = depositAmount; // 1:1 ratio shares since its the initial deposit
        uint256 pricePerShare = bond.pricePerShare(depositAmount, expectedShares);
        vm.expectEmit();
        emit IBond.NewPositionEvent(alice, depositAmount, one_year_maturity, expectedShares, pricePerShare);
        bond.deposit{value: depositAmount}(address(alice), depositAmount, isPtLocked, '');

        IPTv1 pt = IPTv1(bond.pt());
        IYTv1 yt = IYTv1(bond.yt());

        // assert balances update after deposit
        assertEq(pt.balanceOf(alice), depositAmount);
        assertEq(yt.balanceOf(alice), depositAmount / 2); // half pt for 6 months
        assertEq(bond.totalShares(), depositAmount); // 1:1 ratio shares since its the initial  deposit
        assertEq(bond.totalAssets(), depositAmount); // 1:1
    }

    function test_adapter_requestUnstake() public {
        uint96 maturity_6_months = uint96(block.timestamp + 180 days);
        bool isPtLocked = true;
        uint256 depositAmount = 1 ether;
        IBond bond = IBond(_initBond(address(swEthVault), maturity_6_months));

        // create & fund user
        address alice = _createUser('user_adapter_requestUnstake', depositAmount);
        vm.startPrank(alice);

        // create bond
        bond.deposit{value: depositAmount}(alice, depositAmount, isPtLocked, '');

        // assert shares in bond before unstaking
        assertEq(bond.totalShares(), depositAmount);

        // move time to maturity to request unstake
        vm.warp(block.timestamp + maturity_6_months + 1);
        uint256 exitTicket = bond.requestUnstake(address(alice));
        uint256 queuePosition = bond.getExitQueueIndex(exitTicket);

        // assert contract stored the exit ticket correctly
        IBond.ExitRequest memory exitRequest = bond.exitRequest();
        assertEq(exitRequest.timestamp, block.timestamp);
        assertEq(exitRequest.exitTicket, 0); // only req on queue

        // assert shares where transfered from bond to staking vault
        assertEq(bond.totalShares(), 0);
        vm.stopPrank();
    }

    function test_adapter_unstake() external {
        uint96 maturity_6_months = uint96(block.timestamp + 180 days);
        bool isPtLocked = false;
        uint256 depositAmount = 2 ether;
        IBond bond = IBond(_initBond(address(swEthVault), maturity_6_months));

        // create & fund user
        address charlie = _createUser('user_adapter_unstake', depositAmount);
        vm.startPrank(charlie);
        bond.deposit{value: depositAmount}(address(charlie), depositAmount, isPtLocked, '');

        // warp time to maturity
        vm.warp(block.timestamp + maturity_6_months + 1);

        // request unstake before unstaking
        uint256 exitTicket = bond.requestUnstake(charlie);
        swEthVault.updateExitQueue();

        // assert the bond is empty of shares and assets after requesting exit queue
        assertEq(bond.totalAssets(), 0);
        assertEq(bond.totalShares(), 0);

        // assert Eth funds are on staking vault before unstake and not on bond
        assertEq(address(bond).balance, 0);

        // unstake call
        bond.unstake(address(charlie));

        // assert shares where transfered from bond to staking vault
        assertEq(bond.totalShares(), 0);

        // assert Eth funds are on bond after unstake
        assertGt(address(bond).balance, 0);

        // assert contract stored the exit ticket correctly
        IBond.ExitRequest memory exitRequest = bond.exitRequest();
        assertEq(exitRequest.timestamp, block.timestamp);
        assertEq(exitRequest.exitTicket, 0); // onlyone on queue
        assertEq(exitRequest.yieldAssets, address(bond).balance - IPTv1(bond.pt()).totalSupply());
        assertEq(exitRequest.counter, 1);

        vm.stopPrank();
    }

    function test_adapter_redeem(address _redeemToken, uint256 _amount, uint96 _maturity) external {
        uint96 maturity_3_years = uint96(block.timestamp + (ONE_YEAR_SECONDS * 3));
        bool isPtLocked = false;
        uint256 depositAmount = 25 ether;
        IBond bond = IBond(_initBond(address(swEthVault), maturity_3_years));
        IPTv1 pt = IPTv1(bond.pt());
        IYTv1 yt = IYTv1(bond.yt());

        address redeemer = _createUser('user_adapter_redeem', depositAmount);
        vm.startPrank(redeemer);
        bond.deposit{value: depositAmount}(address(redeemer), depositAmount, isPtLocked, '');

        assertEq(pt.balanceOf(address(redeemer)), depositAmount);
        assertEq(yt.balanceOf(address(redeemer)), (depositAmount * 3));

        vm.warp(block.timestamp + maturity_3_years + 1);

        // request unstake before unstaking
        uint256 exitTicket = bond.requestUnstake(redeemer);
        swEthVault.updateExitQueue();

        bond.unstake(redeemer);
        IBond.ExitRequest memory exitRequest = bond.exitRequest();

        vm.expectEmit();
        emit IBond.PositionRedeemEvent(address(redeemer), address(pt), pt.balanceOf(address(redeemer)));
        bond.redeem(redeemer, address(pt), pt.balanceOf(address(redeemer)));

        vm.expectEmit();
        emit IBond.PositionRedeemEvent(address(redeemer), address(yt), exitRequest.yieldAssets.wadDiv(yt.balanceOf(redeemer)));
        bond.redeem(redeemer, address(yt), yt.balanceOf(address(redeemer)));
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   TEST EXTERNAL VIEW FUNCTIONS                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_getMatuirtyDate() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.getMatuirtyDate(), block.timestamp + 180 days);
    }

    function test_router() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.router(), address(router));
    }

    function test_vault() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.vault(), address(swEthVault));
    }

    function test_rewardsVault() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.rewardsVault(), address(keeper));
    }

    function test_capacity() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.capacity(), swEthVault.capacity());
    }

    function test_timeToMaturity() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.timeToMaturity(), 180 days);
    }

    function test_isHarvestRequired() public {
        IBond bond = IBond(_initBond(address(swEthVault), uint96(block.timestamp + 180 days)));
        assertEq(bond.isHarvestRequired(), false);
    }
}
