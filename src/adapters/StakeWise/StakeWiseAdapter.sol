// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from 'openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';
import {IEthVault, IKeeperRewards} from './interfaces/IEthVault.sol';
import {IPyeRouterV1} from '../../interfaces/IPyeRouterV1.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {PTv1} from '../../tokens/PTv1.sol';
import {YTv1} from '../../tokens/YTv1.sol';
import {IBond} from '../../interfaces/IBond.sol';
import {LibString} from 'solady/utils/LibString.sol';
import {WadRayMath} from '../../libs/WadRayMath.sol';

import {ExpiryUtils} from '../../libs/ExpiryUtils.sol';

/// @title StakeWise Adapter implementation
/// @notice Requires Linked libraries: ExpiryUtils prior deployment
contract StakeWiseAdapter is IBond, Initializable {
    using Math for uint256;
    using LibString for uint256;
    using WadRayMath for uint256;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       IMMUTABLES                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 private immutable PRECISION_FACTOR = 1e18;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public constant ONE_YEAR_SECONDS = 31_536_000;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 immutable RAY_PRECISION = 1e27;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public immutable MAX_BPS = 10_000;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        STORAGE                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Admin of this contract
    IPyeRouterV1 private _router;

    // Staking vault
    IEthVault private _ethVault;

    // Rewards Manager Keeper oracle
    IKeeperRewards private immutable _rewardsVault;

    // Fee storage
    PlatformFees private _fees;

    // Exist request storage
    ExitRequest private _exitRequest;

    // PT & YT tokens
    address private _pt;
    address private _yt;

    address private _feeRecipient;

    // single maturity day of this contract
    uint96 private _maturityDate;

    // Staking Vault namespace
    string private _validatorName;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTRUCTOR                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    constructor(string memory validatorName_, address _keeper) {
        _rewardsVault = IKeeperRewards(_keeper);
        _validatorName = validatorName_;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       MODIFIERS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    modifier onlyRouter() {
        require(msg.sender == address(_router), 'Auth Error');
        _;
    }

    modifier onlyValidRequest(address _sender) {
        if (msg.sender == address(_router)) {
            if (PTv1(_pt).balanceOf(_sender) < 1 && YTv1(_yt).balanceOf(_sender) < 1) revert OnlyPyeTokenHolders(0);
        } else {
            if (msg.sender != _sender) revert OnlyPyeTokenHolders(1);
            if (PTv1(_pt).balanceOf(msg.sender) < 1 && YTv1(_yt).balanceOf(msg.sender) < 1) revert OnlyPyeTokenHolders(2);
        }
        if (block.timestamp < _maturityDate) revert MaturityError();
        _;
    }

    receive() external payable {}

    fallback() external payable {
        revert('Unsupported Operation');
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       INTIALIZER                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function initialize(address _validator, uint96 maturityDate_) external payable override initializer {
        _ethVault = IEthVault(_validator);

        // sets router address
        _router = IPyeRouterV1(msg.sender);

        // sets maturity date on storage var
        _maturityDate = maturityDate_;

        // deploys and names Pt & Yt - sets pt & yt storgae fields
        (address pt, address yt) = _createPyeTokens(_validatorName, maturityDate_);
        // load tokens to storage
        _pt = pt;
        _yt = yt;
        emit InitializeBond(pt, yt, address(_ethVault), _maturityDate);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                             STATE CHANGE PERMISSIONED FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(address _sender, uint256 _amount, bool _isPtLocked, bytes calldata _data) external payable override {
        if (msg.value < _amount) revert InsufficientEth();
        if (block.timestamp > _maturityDate) revert MaturityError();
        uint256 shares = _deposit(_amount, _data);
        uint256 pricePerShare = _pricePerShare(_amount, shares);

        PTv1(_pt).mint(_sender, _amount, _isPtLocked);
        YTv1(_yt).mint(_sender, _getYtAmount(_amount, _maturityDate));
        emit NewPositionEvent(_sender, _amount, _maturityDate, shares, pricePerShare);
    }

    /// @notice Called on position contract creation (initialize function)
    /// @dev deposits the principal amount to the SW vault
    /// @param data Off-chain HarvestParams in case SW vault requires update trigger
    /// @param _principal The amount of the asset to stake
    function _deposit(uint256 _principal, bytes calldata data) internal returns (uint256 _shares) {
        // data is off-chain data sent by UI, requires MKT rewrds proof
        if (data.length > 0) {
            // harvestParams at least 136 bytes
            IKeeperRewards.HarvestParams memory harvestParams = _decodeHarvestParams(data);
            _shares = _ethVault.updateStateAndDeposit{value: _principal}(address(this), address(0), harvestParams);
        } else {
            _shares = _ethVault.deposit{value: _principal}(address(this), address(0)); // sw interface sender, referrer
        }
    }

    /// @notice Request total available shares to enter the SW exit queue
    /// @dev access: any PYE token holder
    /// @dev if call comes from router evaluate _sender param else evaluate msg.sender for access
    function requestUnstake(address _sender) external override onlyValidRequest(_sender) returns (uint256 _positionTicket) {
        ExitRequest memory exitRequest = _exitRequest;

        uint256 shares = _ethVault.getShares(address(this));

        // request enter exit queue for the total of shares
        // note: second request will revert
        _positionTicket = _ethVault.enterExitQueue(shares, address(this));

        // track enterExitQueue details for unstake
        exitRequest.exitTicket = _positionTicket;
        exitRequest.timestamp = block.timestamp;
        _exitRequest = exitRequest;

        emit EnterExitQueueEvent(msg.sender, shares, _positionTicket, block.timestamp);
    }

    /// @notice Access any pye token holder of > 1 share
    /// @dev if call comes from router evaluate _sender param else evaluate msg.sender for access
    function unstake(address _sender) external override onlyValidRequest(_sender) {
        ExitRequest memory request = _exitRequest;
        // if more than one request, check if there are shares to claim
        if (request.counter > 0) {
            (uint256 leftShares,,) = calculateExitedAssets();
            if (leftShares < 1) revert NothingToClaimError();
        }

        (uint256 newPositionTicket, uint256 claimedShares, uint256 claimedAssets) = _ethVault.claimExitedAssets(request.exitTicket, request.timestamp, getExitQueueIndex(request.exitTicket));

        if (address(this).balance < claimedAssets) revert UnstakeTransferError();
        request.exitSharePrice = _pricePerShare(claimedAssets, claimedShares);

        request.exitTicket = newPositionTicket;
        request.timestamp = block.timestamp;

        request.yieldAssets = claimedAssets - PTv1(_pt).totalSupply();
        request.counter += 1;

        // update storage
        _exitRequest = request;
        emit UnstakeEvent(msg.sender, newPositionTicket, claimedShares, claimedAssets, request.yieldAssets);
    }

    function redeem(address _sender, address _token, uint256 _amount) external override {
        // check the caller has the token amount to redeem
        _validateRedeemRequest(_sender, _token, _amount);

        (uint256 leftShares,,) = calculateExitedAssets();
        // enable redeem until NO shares on undstake queue
        if (leftShares > 0) revert SharesOnQueueError();

        // sload available & withdrawn assets
        ExitRequest memory exit = _exitRequest;
        uint256 redeemAssets;

        // check if redeem is from principal or yield tranche
        if (_token == _pt) {
            // burn shares then send assets to user
            PTv1(_pt).burn(_sender, _amount);
            redeemAssets = _amount - _protocolFees(_amount);
            _sendValue(payable(_sender), redeemAssets);
        } else if (_token == _yt) {
            // yieldAssets is in wei
            redeemAssets = exit.yieldAssets.wadDiv(_amount);

            // burn shares then send assets to receiver (user)
            YTv1(_yt).burn(_sender, _amount);
            _sendValue(payable(_sender), redeemAssets - _protocolFees(redeemAssets));
        }
        _exitRequest = exit;
        emit PositionRedeemEvent(_sender, _token, redeemAssets);
    }

    function updateFeeRecipient(address _feeRecipient, uint80 _fee) external override onlyRouter returns (bool) {
        _fees = PlatformFees({feeRecipient: _feeRecipient, feeBp: _fee});
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   EXTERNAL VIEW FUNCTIONS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function getMatuirtyDate() external view returns (uint96) {
        return _maturityDate;
    }

    function router() external view override returns (address) {
        return address(_router);
    }

    function pt() external view override returns (address) {
        return address(_pt);
    }

    function yt() external view override returns (address) {
        return address(_yt);
    }

    function vault() external view override returns (address) {
        return address(_ethVault);
    }

    function rewardsVault() external view override returns (address) {
        return address(_rewardsVault);
    }

    function getShares() external view override returns (uint256) {
        return _ethVault.getShares(address(this));
    }

    function capacity() external view returns (uint256) {
        return _ethVault.capacity();
    }

    function timeToMaturity() external view override returns (uint256) {
        return _maturityDate - block.timestamp;
    }

    function isHarvestRequired() external view returns (bool) {
        return _rewardsVault.isHarvestRequired(address(_ethVault));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   PUBLIC VIEW FUNCTIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function exitRequest() external view override returns (ExitRequest memory) {
        return _exitRequest;
    }

    function getExitQueueIndex(uint256 _exitTicket) public view override returns (uint256) {
        return uint256(_ethVault.getExitQueueIndex(_exitTicket));
    }

    function convertToAssets(uint256 shares) external view override returns (uint256 assets) {
        return _ethVault.convertToAssets(shares);
    }

    function totalAssets() external view override returns (uint256 assets) {
        return _ethVault.convertToAssets(_ethVault.getShares(address(this)));
    }

    function totalShares() external view override returns (uint256 assets) {
        return _ethVault.getShares(address(this));
    }

    function calculateExitedAssets() public view returns (uint256, uint256, uint256) {
        ExitRequest memory exitRequest = _exitRequest;
        return _ethVault.calculateExitedAssets(address(this), exitRequest.exitTicket, exitRequest.timestamp, exitRequest.exitTicket);
    }

    function pricePerShare(uint256 deposit_, uint256 _shares) external view returns (uint256) {
        return _pricePerShare(deposit_, _shares);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   INTERNAL FUNCTIONS                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice IF router contract is calling the function, validate sender's balance
    function _validateRedeemRequest(address sender, address token, uint256 amount) internal view {
        if (msg.sender == address(_router)) {
            if (IERC20(token).balanceOf(sender) < amount) revert OnlyPyeTokenHolders(3);
        } else {
            if (IERC20(token).balanceOf(msg.sender) < amount) revert OnlyPyeTokenHolders(4);
        }
    }

    function _decodeHarvestParams(bytes memory data) internal pure returns (IKeeperRewards.HarvestParams memory) {
        (bytes32 rewardsRoot, int192 reward, uint192 unlockedMevReward, bytes32[] memory proof) = abi.decode(data, (bytes32, int192, uint192, bytes32[]));
        return IKeeperRewards.HarvestParams(rewardsRoot, reward, unlockedMevReward, proof);
    }

    function _percent(uint256 amount, uint96 bps) internal view returns (uint256 _percentAmt) {
        require(bps <= MAX_BPS, 'Wrong percent');
        _percentAmt = amount.mulDiv(bps, MAX_BPS);
    }

    /// @notice Extract from OZ address lib
    function _sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert InsufficientBalanceError(address(this));
        }

        (bool success,) = recipient.call{value: amount}('');
        if (!success) {
            revert TransferFailedError();
        }
    }

    function _pricePerShare(uint256 deposit_, uint256 _shares) internal view returns (uint256 _rate) {
        uint256 sharesValue = _ethVault.convertToAssets(_shares);
        _rate = sharesValue.mulDiv(PRECISION_FACTOR, deposit_);
    }

    function _formatTokenNameAndSymbol(string memory _validatorName, uint96 _maturity) internal returns (string memory _name, string memory _symbol) {
        string memory rfc2822String = ExpiryUtils.toRFC2822String(_maturity);
        _name = string(abi.encodePacked(_validatorName, ' ', rfc2822String));
        _symbol = string(abi.encodePacked('SWETH-', rfc2822String));
    }

    function _getYtAmount(uint256 _principal, uint96 _maturity) internal returns (uint256 _ytAmount) {
        uint256 period = uint96(_maturity - block.timestamp); // 1 year lock is APY = 100%
        uint256 ratePerSec = _principal.rayDiv(ONE_YEAR_SECONDS); // 1e27 rayDiv rounds half up to the nearest ray
        _ytAmount = period * ratePerSec / RAY_PRECISION;
    }

    function _createPyeTokens(string memory _validatorName, uint96 _maturity) internal returns (address _pt, address _yt) {
        (string memory _name, string memory _symbol) = _formatTokenNameAndSymbol(_validatorName, _maturity);
        // create and Name PT & YT tokens
        _pt = address(new PTv1(LibString.concat('PT ', _name), LibString.concat('PT-', _symbol)));
        _yt = address(new YTv1(LibString.concat('YT ', _name), LibString.concat('YT-', _symbol)));
    }

    function _protocolFees(uint256 _assets) internal returns (uint256 _feeAmt) {
        PlatformFees memory fees = _fees; // sload fees
        _feeAmt = _percent(_assets, fees.feeBp);
        _sendValue(payable(fees.feeRecipient), _feeAmt);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
