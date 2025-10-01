// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console, Vm} from 'forge-std/Test.sol';
import {StakeWiseAdapter} from '../../src/adapters/StakeWise/StakeWiseAdapter.sol';

// Test StakeWiseAdapter.sol internal functions
contract StakeWiseAdapterInternalTest is StakeWiseAdapter('TestVault', address(0x0)), Test {
    string constant ETHEREUM_MAINNET = 'https://mainnet.infura.io/v3/0f16b26af1dc41ceb5ebf74a86e1d5b3';

    function setUp() public {
        vm.createSelectFork(ETHEREUM_MAINNET);
        console.log('init test time', vm.getBlockTimestamp());
    }

    uint256 internal constant RAY = 1e27;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   INTERNAL FUNCTIONS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_py_amt_1qtr_maturity() public {
        uint256 _principal = 100 ether;
        uint80 _maturity = uint80(block.timestamp + 91.25 days);

        uint256 ytAmount = super._getYtAmount(_principal, _maturity);

        uint256 period = _maturity - block.timestamp;

        if (period > ONE_YEAR_SECONDS) {
            uint256 period = period * RAY_PRECISION / ONE_YEAR_SECONDS;
            assertEq(ytAmount, period * _principal / RAY_PRECISION);
        } else {
            uint256 period = ONE_YEAR_SECONDS * RAY_PRECISION / period;
            assertEq(_principal, (ytAmount * period) / RAY_PRECISION);
        }
    }

    function test_py_amt_biAnnual_maturity() public {
        uint256 _principal = 100 ether;
        uint80 _maturity = uint80(block.timestamp + 182.5 days);
        uint256 period = _maturity - block.timestamp;

        uint256 ytAmount = super._getYtAmount(_principal, _maturity);

        if (period > ONE_YEAR_SECONDS) {
            uint256 period = period * RAY_PRECISION / ONE_YEAR_SECONDS;
            assertEq(ytAmount, period * _principal / RAY_PRECISION);
        } else {
            uint256 period = ONE_YEAR_SECONDS * RAY_PRECISION / period;
            assertEq(_principal, (ytAmount * period) / RAY_PRECISION);
        }
    }

    function test_py_amt_2yrs_maturity() public {
        uint256 _principal = 100 ether;
        uint80 _maturity = uint80(block.timestamp + 730 days);
        uint256 period = _maturity - block.timestamp;

        uint256 ytAmount = super._getYtAmount(_principal, _maturity);

        if (period > ONE_YEAR_SECONDS) {
            uint256 period = period * RAY_PRECISION / ONE_YEAR_SECONDS;
            assertEq(ytAmount, period * _principal / RAY_PRECISION);
        } else {
            uint256 period = ONE_YEAR_SECONDS * RAY_PRECISION / period;
            assertEq(_principal, (ytAmount * period) / RAY_PRECISION);
        }
    }

    // /// @notice We use assertApproxEqAbs due to function getYtAmount ray rounding
    function test_fuzz_py_amt_rndm_principal_and_maturity(uint256 _principal, uint80 _maturity) public {
        uint256 principal = bound(_principal, 0.1 ether, 1000 ether);
        uint256 maturity = bound(_maturity, uint80(block.timestamp + 1 days), uint80(block.timestamp + (1825 * 1 days)));

        uint256 roundingTolerance = 1000; // in we, so its less than $0.01 USD

        uint256 ytAmount = super._getYtAmount(principal, uint80(maturity));
        uint256 period = maturity - block.timestamp;

        if (period > ONE_YEAR_SECONDS) {
            uint256 period = period * RAY_PRECISION / ONE_YEAR_SECONDS;
            uint256 proof = period * principal / RAY_PRECISION;
            assertApproxEqAbs(ytAmount, proof, roundingTolerance);
        } else {
            uint256 period = ONE_YEAR_SECONDS * RAY_PRECISION / period;
            uint256 proof = (ytAmount * period) / RAY_PRECISION;
            assertApproxEqAbs(principal, proof, roundingTolerance);
        }
    }

    function test_validateRedeemRequest() public {}
    function test_decodeHarvestParams() public {}
    function test_formatTokenNameAndSymbol() public {}
    function test_percent() public {}
    function test_pricePerShare() public {}
    function test_sendValue() public {}
    function test_createPyeTokens() public {}
    function test_protocolFees() public {}

    function updateFeeRecipient(address _position, address _recipient) external returns (bool) {
        return true;
    }
}
