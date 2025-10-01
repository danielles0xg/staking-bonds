// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PyeRouterV1} from '../../src/PyeRouterV1.1.sol';
import {UpgradeableBeacon} from 'openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol';

import {StakeWiseAdapter} from '../../src/adapters/StakeWise/StakeWiseAdapter.sol';
import {KeeperMock, SwEthVaulMock} from '../../src/mock/SwEthVaulMock.sol';
import {Test, console, Vm} from 'forge-std/Test.sol';
import {IPyeRouterV1} from '../../src/interfaces/IPyeRouterV1.sol';
import {IBond} from '../../src/interfaces/IBond.sol';
import {IPTv1} from '../../src/interfaces/IPTv1.sol';
import {IYTv1} from '../../src/interfaces/IYTv1.sol';
import {BaseTest} from './BaseTest.t.sol';

contract RouterV1Test is BaseTest {
    PyeRouterV1 public router;
    IYTv1 public yt;
    IPTv1 public pt;
    StakeWiseAdapter public adapter;
    SwEthVaulMock public swEthVault;
    KeeperMock public keeper;
    IBond public positionBond;

    address public beacon;
    address public deployer;

    function setUp() public {
        // mock instances
        deployer = _createUser('deployer', 100 ether);
        vm.startPrank(deployer);
        uint256 MOCK_VALIDATOR_APY = 500; // 5% bp
        swEthVault = new SwEthVaulMock{value: 100 ether}(MOCK_VALIDATOR_APY);
        keeper = new KeeperMock(address(swEthVault));
        adapter = new StakeWiseAdapter('SWEth', address(keeper));
        beacon = address(new UpgradeableBeacon(address(adapter), deployer));

        // main intances
        address[] memory validatorVaults = new address[](1);
        validatorVaults[0] = address(swEthVault);
        router = new PyeRouterV1(msg.sender, beacon, 1000, 1000, validatorVaults);
        vm.stopPrank();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 ADMIN FUNCTIONS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_constructor() public {
        vm.startPrank(deployer);
        address[] memory validatorVaults = new address[](1);
        validatorVaults[0] = address(swEthVault);
        router = new PyeRouterV1(msg.sender, beacon, 1000, 1000, validatorVaults);
        assertEq(router.admin(), deployer);
        assertEq(router.defaultBeacon(), beacon);
        assertEq(router.mintFee(), 1000);
        assertEq(router.redemptionFee(), 1000);
        assertEq(router.validators(0), address(swEthVault));
        vm.stopPrank();
    }

    function test_addValidatorVault() public {
        vm.startPrank(deployer);
        address newVault = address(new SwEthVaulMock(500));
        router.addValidatorVault(newVault);
        assertEq(router.validators(1), newVault);
    }

    function test_removeValidatorVault() public {
        vm.startPrank(deployer);
        address newVault = address(new SwEthVaulMock(500));
        router.addValidatorVault(newVault);
        router.removeValidatorVault(newVault);
        assertEq(router.isValidatorVault(newVault), false);
    }

    function test_removeValidatorVault_not_exists() public {
        vm.expectRevert();
        router.removeValidatorVault(address(1));
    }

    function test_removeValidatorVault_by_index() public {
        vm.startPrank(deployer);
        address newVault = address(new SwEthVaulMock(500));
        router.addValidatorVault(newVault);
        router.removeValidatorVault(1);
        assertEq(router.validators(1), address(0));
    }

    function test_updateMintFee() public {
        vm.startPrank(deployer);
        uint256 newFee = 2000;
        router.updateMintFee(newFee);
        assertEq(router.mintFee(), newFee);
    }

    function test_updateRedemptionFee() public {
        vm.startPrank(deployer);
        uint256 newFee = 2000;
        router.updateRedemptionFee(newFee);
        assertEq(router.redemptionFee(), newFee);
    }

    function test_editFeeRecipient() public {
        vm.startPrank(deployer);
        address newRecipient = address(1);
        router.editFeeRecipient(newRecipient);
        assertEq(router.feeRecipient(), newRecipient);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 ROUTER FACTORY FUNCTIONS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _deployBond(uint96 maturity) internal returns (IPyeRouterV1.BondStorage memory _adapter) {
        _adapter = router.createBond(address(swEthVault), maturity);
        pt = IPTv1(_adapter.ptAddress);
        yt = IYTv1(_adapter.ytAddress);
    }

    function test_createBond() public {
        uint96 maturity = uint96(block.timestamp + SIX_MONTH_SECONDS);
        IPyeRouterV1.BondStorage memory bondRecord = _deployBond(maturity);
        assert(bondRecord.bondAddress != address(0));
        assertEq(bondRecord.maturity, maturity);
    }

    function test_pt_transfer_lock() public {
        uint96 maturity = uint96(block.timestamp + SIX_MONTH_SECONDS);
        address validatorVault = address(swEthVault);
        bool isPtLocked = true;
        uint256 depositAmount = 1 ether;
        IPyeRouterV1.BondStorage memory bondRecord = _deployBond(maturity);
        pt = IPTv1(bondRecord.ptAddress);
        router.deposit{value: depositAmount}(address(this), 1 ether, validatorVault, maturity, isPtLocked, '');
        uint256 ptBalance = pt.balanceOf(address(this));

        // transfer locked pt
        vm.expectRevert();
        pt.transfer(address(1), ptBalance);
    }

    function test_router_deposit_and_crreate_bond_if_not_exists() public {
        uint256 depositAmount = 1 ether;
        uint96 maturity = uint96(block.timestamp + ONE_YEAR_SECONDS);
        bool isPtLocked = true;
        address validatorVault = address(swEthVault);

        IPyeRouterV1.BondStorage memory bondStorage = router.deposit{value: depositAmount}(address(this), depositAmount, validatorVault, maturity, isPtLocked, '');
        assertEq(IPTv1(bondStorage.ptAddress).balanceOf(address(this)), depositAmount);
        assertEq(IYTv1(bondStorage.ytAddress).balanceOf(address(this)), depositAmount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 ADAPTER FUNCTIONS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_router_deposit() public {
        uint256 depositAmount = 1 ether;
        uint96 maturity = uint96(block.timestamp + SIX_MONTH_SECONDS); // 6 months
        bool isPtLocked = true;
        address validatorVault = address(swEthVault);
        _deployBond(maturity);

        address alice = _createUser('alice_router_deposit', depositAmount);
        vm.startPrank(alice);

        // alice deposits 3 months to bond maturity
        vm.warp(block.timestamp + THREE_MONTH_SECONDS);
        IPyeRouterV1.BondStorage memory bondStorage = router.deposit{value: depositAmount}(address(alice), depositAmount, validatorVault, maturity, isPtLocked, '');

        //ssert pt minted calling from raouter 1:1
        assertEq(IPTv1(bondStorage.ptAddress).balanceOf(address(alice)), depositAmount);

        // assert yt minted calling from raouter
        assertEq(IYTv1(bondStorage.ytAddress).balanceOf(address(alice)), depositAmount / 4);
    }

    function test_router_requestUnstake() public {
        // position params
        uint96 maturity = uint96(block.timestamp + 180 days);
        uint256 depositAmount = 10 ether;
        bool isPtLocked = true;
        address validatorVault = address(swEthVault);

        // deploy bond
        IPyeRouterV1.BondStorage memory bondStorage = _deployBond(maturity);
        IBond bondInstance = IBond(bondStorage.bondAddress);

        // deposit
        address bob = _createUser('bob_router_reqUnstake', depositAmount);
        vm.startPrank(bob);
        bondInstance.deposit{value: depositAmount}(address(bob), depositAmount, isPtLocked, '');

        // time travel to  maturity + 1
        vm.warp(block.timestamp + 181 days);

        // assert Eth funds are on staking vault before unstake and not on bond
        assertEq(bondInstance.totalShares(), depositAmount);

        // request unstake
        vm.expectEmit();
        emit IPyeRouterV1.UnstakeRequestedEvent(bob, validatorVault, maturity);
        router.requestUnstake(validatorVault, maturity);

        // assert shares where transfered from bond to staking vault
        assertEq(bondInstance.totalShares(), 0);
    }

    function test_router_unstake() public {
        // position params
        uint96 maturity = uint96(block.timestamp + 180 days);
        uint256 depositAmount = 100 ether;
        bool isPtLocked = true;
        address validatorVault = address(swEthVault);

        // deploy bond
        IPyeRouterV1.BondStorage memory bondInstance = _deployBond(maturity);
        IBond bond = IBond(bondInstance.bondAddress);

        // deposit
        address charlie = _createUser('bob_router_reqUnstake', depositAmount);
        vm.startPrank(charlie);
        bond.deposit{value: depositAmount}(address(charlie), depositAmount, isPtLocked, '');

        // move time to  maturity + 1 days
        vm.warp(block.timestamp + 181 days);

        // request unstake
        router.requestUnstake(validatorVault, maturity);
        swEthVault.updateExitQueue();

        // unstake
        router.unstake(validatorVault, maturity);
    }

    function test_router_redeem() public {
        // position params
        uint96 maturity = uint96(block.timestamp + 180 days);
        uint256 depositAmount = 100 ether;
        bool isPtLocked = true;
        address validatorVault = address(swEthVault);

        // deploy bond
        IPyeRouterV1.BondStorage memory bondInstance = _deployBond(maturity);
        yt = IYTv1(bondInstance.ytAddress);
        pt = IPTv1(bondInstance.ptAddress);
        IBond bond = IBond(bondInstance.bondAddress);

        // deposit
        bond.deposit{value: depositAmount}(address(this), depositAmount, isPtLocked, '');

        // time travel to  maturity + 1
        vm.warp(block.timestamp + 181 days);

        // request unstake
        router.requestUnstake(validatorVault, maturity);
        swEthVault.updateExitQueue();

        // unstake
        router.unstake(validatorVault, maturity);

        // redeem
        router.redeem(address(yt), yt.balanceOf(address(this)), validatorVault, maturity);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 UPGRADABLE BEACON FUNCTIONS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_updateDefaultBeacon() public {
        vm.startPrank(deployer);
        address newBeacon = address(new UpgradeableBeacon(address(adapter), msg.sender));
        router.updateDefaultBeacon(newBeacon);
        assertEq(router.defaultBeacon(), newBeacon);
    }

    function test_upgradeAdapter() public {
        vm.startPrank(deployer);
        // create a bond with default beacon deployed on setup function (Router constructor)
        // keeper address is set into adapter immutable storage at deploy time
        uint96 maturity = uint96(block.timestamp + SIX_MONTH_SECONDS);
        IPyeRouterV1.BondStorage memory bondStorage = router.createBond(address(swEthVault), maturity);
        IBond bond = IBond(bondStorage.bondAddress);

        // assert bond rewards Vault is keeper address
        assertEq(bond.rewardsVault(), address(keeper));

        // get UpgradeableBeacon contract
        UpgradeableBeacon beacon = UpgradeableBeacon(beacon);

        // deploy new adapter with new storage values (rewards/keeper address)
        StakeWiseAdapter adapter = new StakeWiseAdapter('SWEth', address(1));

        // upgrade beacon to new adapter
        beacon.upgradeTo(address(adapter));

        // assert same bond rewards Vault is updated
        assertEq(bond.rewardsVault(), address(1));
        vm.stopPrank();
    }

    fallback() external payable {}
}
