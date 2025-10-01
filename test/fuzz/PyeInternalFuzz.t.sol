// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {PyeToken} from "../../src/PyeToken.sol";
import {Registry} from "../../src/Registry.sol";
import {Schedules} from "../../src/Schedules.sol";

// Test PyeToken.sol internal functions
contract PyeInternalTest is PyeToken(address(0x0), address(0x0)), Test {
    Registry public registry;
    Schedules public schedules;

    // using mainnet current block timestamp
    string constant MAINNET_URL = "https://mainnet.infura.io/v3/0f16b26af1dc41ceb5ebf74a86e1d5b3";

    function setUp() public {
        registry = new Registry();
        schedules = new Schedules();
        vm.createSelectFork(MAINNET_URL);
    }

    uint256 internal constant RAY = 1e27;

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

    /// @notice We use assertApproxEqAbs due to function getYtAmount ray rounding
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

    function updateFeeRecipient(address _position, address _recipient) external returns (bool) {
        return true;
    }
}
