// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from 'openzeppelin-contracts/contracts/utils/math/Math.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';

import {Test, console, Vm} from 'forge-std/Test.sol';

import {ExitQueue, Errors} from './ExitQueue.sol';

contract SwEthVaulMock {
    using Math for uint256;
    using ExitQueue for ExitQueue.History;

    error ZeroAddress();
    error InvalidAssets();

    ExitQueue.History internal _exitQueue;
    mapping(bytes32 => uint256) internal _exitRequests;
    mapping(address => uint256) internal _balances;

    uint128 internal _totalShares;
    uint256 internal _totalAssets;
    uint128 internal _unclaimedAssets;
    uint256 private _exitingAssetsClaimDelay;
    uint256 internal _capacity;

    uint256 private queuedShares;
    uint256 internal lastUpdateBlock;

    uint64 internal rewardsPerBlock = 0.001 ether; // arbitrary number
    uint256 public constant ONE_YEAR_SECONDS = 31_536_000;
    uint256 public constant RAY_PRECISION = 1e27;
    uint256 public APY;

    event Log(string message, uint256 value);
    event CheckpointCreated(uint256 shares, uint256 assets);
    event SharesMinted(address indexed owner, uint256 shares);
    event ExitQueueUpdated(uint256 burnedShares, uint256 exitedAssets);
    event UpdatedRewardsEvent(uint256 shares, uint256 elapsed, uint192 periodRewards);
    event Deposited(address indexed from, address indexed to, uint256 assets, uint256 shares, address referrer);
    event ExitQueueEntered(address indexed user, address indexed receiver, uint256 positionTicket, uint256 shares);
    event ExitedAssetsClaimed(address indexed receiver, uint256 positionTicket, uint256 newPositionTicket, uint256 claimedAssets);
    event CalculateExitedAssetsEvent(uint256 leftShares, uint256 claimedShares, uint256 claimedAssets);

    event LogRewards(string a, uint256 b);

    struct HarvestParams {
        bytes32 rewardsRoot;
        int160 reward;
        uint160 unlockedMevReward;
        bytes32[] proof;
    }

    uint256 private _shares;
    uint192 public rewards;
    uint256 private _lastRewardUpdate;
    uint256 private _rewardsPerBlock = 0.001 ether;

    mapping(address => uint256) public deposits;

    modifier _updateRewards() {
        uint256 secondsElapsed = block.timestamp - _lastRewardUpdate;
        uint256 rewardsPerSecond = _percent(_totalAssets, uint96(APY)) / ONE_YEAR_SECONDS;
        emit LogRewards('rewardsPerSecond:: ', rewardsPerSecond);
        // acrrue rewards on _totalAssets as SW does
        uint192 periodRewards = uint192(secondsElapsed * rewardsPerSecond);
        rewards += periodRewards;
        _totalAssets += periodRewards;
        _lastRewardUpdate = block.timestamp;

        emit UpdatedRewardsEvent(_totalAssets, secondsElapsed, periodRewards);
        _;
    }

    // /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    // /*                     init mock state                        */
    // /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    constructor(uint256 _apy) payable {
        // require(msg.value > 10 ether, 'totalAssets < 10 ether');
        APY = _apy;
        // lastUpdateBlock = block.timestamp;
        // _totalAssets = msg.value;
        // _totalShares = uint128(msg.value);
        _capacity = type(uint256).max;
        uint256 rewardsPerSecond = _percent(_totalAssets, uint96(APY)) / ONE_YEAR_SECONDS;
        emit LogRewards('rewardsPerSecond:: ', rewardsPerSecond);
    }

    function updateVaultApy(uint256 _newApy) external payable {
        APY = _newApy;
        uint256 rewardsPerSecond = _percent(_totalAssets, uint96(APY)) / ONE_YEAR_SECONDS;
        emit LogRewards('rewardsPerSecond:: ', rewardsPerSecond);
    }

    function updateVaultState(uint256 _totalAssets, uint256 totalShares_) external {
        _totalAssets = _totalAssets;
        _totalShares = uint128(totalShares_);
        lastUpdateBlock = block.number;
    }
    // /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    // /*                     DEposit                                */
    // /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    function isStateUpdateRequired() external returns (bool) {
        return false;
    }

    function updateStateAndDeposit(address receiver, address referrer, HarvestParams calldata harvestParams) external payable returns (uint256 shares) {}

    function deposit(address to, address referrer) external payable _updateRewards returns (uint256 shares) {
        uint256 assets = msg.value;
        // _checkHarvested();
        if (to == address(0)) revert ZeroAddress();
        if (assets == 0) revert InvalidAssets();

        uint256 totalAssetsAfter = _totalAssets + assets;

        // calculate amount of shares to mint
        shares = _convertToShares(assets, Math.Rounding.Ceil);

        // update state
        _totalAssets = SafeCast.toUint128(totalAssetsAfter);
        _mintShares(to, shares);

        emit Deposited(msg.sender, to, assets, shares, referrer);
    }

    // /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    // /*                     Enter Exit                              */
    // /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    function enterExitQueue(uint256 shares, address receiver) public _updateRewards returns (uint256 positionTicket) {
        return _enterExitQueue(msg.sender, shares, receiver);
    }

    function _enterExitQueue(address user, uint256 shares, address receiver) internal virtual returns (uint256 positionTicket) {
        // _checkCollateralized();
        if (shares == 0) revert Errors.InvalidShares();
        if (receiver == address(0)) revert Errors.ZeroAddress();

        // SLOAD to memory
        uint256 _queuedShares = queuedShares;

        // calculate position ticket
        positionTicket = _exitQueue.getLatestTotalTickets() + _queuedShares;

        // add to the exit requests
        _exitRequests[keccak256(abi.encode(receiver, block.timestamp, positionTicket))] = shares;

        // reverts if owner does not have enough shares
        _balances[user] -= shares;

        unchecked {
            // cannot overflow as it is capped with _totalShares
            queuedShares = SafeCast.toUint128(_queuedShares + shares);
        }

        emit ExitQueueEntered(user, receiver, positionTicket, shares);
    }

    // /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    // /*                     REDEEM                                 */
    // /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/
    event ExitRequest(string message, uint256 exitRequest);

    function claimExitedAssets(uint256 positionTicket, uint256 timestamp, uint256 exitQueueIndex) external returns (uint256 newPositionTicket, uint256 claimedShares, uint256 claimedAssets) {
        if (block.timestamp < timestamp + _exitingAssetsClaimDelay) revert Errors.ClaimTooEarly();
        bytes32 queueId = keccak256(abi.encode(msg.sender, timestamp, positionTicket));

        // calculate exited shares and assets
        uint256 leftShares;
        (leftShares, claimedShares, claimedAssets) = calculateExitedAssets(msg.sender, positionTicket, timestamp, exitQueueIndex);
        // nothing to claim
        if (claimedShares == 0) return (positionTicket, claimedShares, claimedAssets);

        // clean up current exit request
        delete _exitRequests[queueId];

        // skip creating new position for the shares rounding error
        if (leftShares > 1) {
            // update user's queue position
            newPositionTicket = positionTicket + claimedShares;
            _exitRequests[keccak256(abi.encode(msg.sender, timestamp, newPositionTicket))] = leftShares;
        }

        // transfer assets to the receiver
        _unclaimedAssets -= SafeCast.toUint128(claimedAssets);
        _transferVaultAssets(msg.sender, claimedAssets);
        emit ExitedAssetsClaimed(msg.sender, positionTicket, newPositionTicket, claimedAssets);
    }

    function _transferVaultAssets(address receiver, uint256 assets) internal {
        Address.sendValue(payable(receiver), assets);
    }

    function getExitQueueIndex(uint256 positionTicket) external returns (int256) {
        uint256 checkpointIdx = _exitQueue.getCheckpointIndex(positionTicket);
        return checkpointIdx < _exitQueue.checkpoints.length ? int256(checkpointIdx) : -1;
    }

    function convertToAssets(uint256 shares) public returns (uint256 assets) {
        uint256 totalShares_ = _totalShares;
        return (totalShares_ == 0) ? shares : Math.mulDiv(shares, _totalAssets, totalShares_);
    }

    function capacity() external returns (uint256) {
        return _totalAssets;
    }

    function getShares(address account) external view returns (uint256) {
        return _balances[account];
    }

    function updateState(HarvestParams calldata harvestParams) external {}

    function withdrawableAssets() external returns (uint256) {}

    function calculateExitedAssets(address receiver, uint256 positionTicket, uint256 timestamp, uint256 exitQueueIndex) public view returns (uint256 leftShares, uint256 claimedShares, uint256 claimedAssets) {
        uint256 requestedShares = _exitRequests[keccak256(abi.encode(receiver, timestamp, positionTicket))];

        // calculate exited shares and assets
        (claimedShares, claimedAssets) = _exitQueue.calculateExitedAssets(exitQueueIndex, positionTicket, requestedShares);
        leftShares = requestedShares - claimedShares;
    }

    function _mintShares(address owner, uint256 shares) internal virtual {
        // update total shares
        _totalShares += uint128(shares);

        // mint shares to owner
        _balances[owner] += shares;
        emit SharesMinted(owner, shares);
    }

    function convertToShares(uint256 assets) public returns (uint256 shares) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal returns (uint256 shares) {
        uint256 totalShares_ = _totalShares;
        // Will revert if assets > 0, totalShares > 0 and _totalAssets = 0.
        // That corresponds to a case where any asset would represent an infinite amount of shares.
        return (assets == 0 || totalShares_ == 0) ? assets : Math.mulDiv(assets, totalShares_, _totalAssets, rounding);
    }

    function updateExitQueue() external returns (uint256 burnedShares) {
        // SLOAD to memory
        uint256 _queuedShares = queuedShares;
        if (_queuedShares == 0) return 0;

        // calculate the amount of assets that can be exited
        uint256 unclaimedAssets = _unclaimedAssets;
        uint256 exitedAssets = Math.min(_vaultAssets() - unclaimedAssets, convertToAssets(_queuedShares));
        if (exitedAssets == 0) return 0;

        // calculate the amount of shares that can be burned
        burnedShares = convertToShares(exitedAssets);
        if (burnedShares == 0) return 0;

        // update queued shares and unclaimed assets
        queuedShares = SafeCast.toUint128(_queuedShares - burnedShares);
        _unclaimedAssets = SafeCast.toUint128(unclaimedAssets + exitedAssets);

        // push checkpoint so that exited assets could be claimed
        _exitQueue.push(burnedShares, exitedAssets);
        emit CheckpointCreated(burnedShares, exitedAssets);

        // update state
        _totalShares -= SafeCast.toUint128(burnedShares);
        _totalAssets -= SafeCast.toUint128(exitedAssets);
    }

    function feePercent() external view returns (uint16) {
        return uint16(500); // 5% bp
    }

    function totalAssets() external view virtual returns (uint256) {
        return _totalAssets + rewards;
    }

    function _vaultAssets() internal view virtual returns (uint256) {
        return _totalAssets;
    }

    function _percent(uint256 amount, uint96 bps) internal view returns (uint256 _percentAmt) {
        require(bps <= 10_000, 'Wrong percent');
        _percentAmt = amount.mulDiv(bps, 10_000);
    }
}

interface ISwEthVaulMock {
    function rewards() external returns (int192 assets);
}

contract KeeperMock {
    address public _ethVaultMock;

    constructor(address ethVaultMock_) {
        _ethVaultMock = ethVaultMock_;
    }

    function rewards(address _vault) external returns (int192 assets, uint64 nonce) {
        assets = ISwEthVaulMock(_ethVaultMock).rewards();
        nonce = 1;
    }

    function unlockedMevRewards(address vault) external returns (uint192 assets, uint64 nonce) {
        assets = uint192(1000);
        nonce = uint64(2);
    }

    function isHarvestRequired(address vault) external returns (bool) {
        return false;
    }

    function prevRewardsRoot() external returns (bytes32) {
        return bytes32(0);
    }
}
