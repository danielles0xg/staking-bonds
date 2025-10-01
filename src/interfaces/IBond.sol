// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBond {
    struct PlatformFees {
        address feeRecipient;
        uint80 feeBp; // bp
    }

    struct ExitRequest {
        uint8 counter; // up to 255 unstake requests
        uint256 exitTicket;
        uint256 timestamp;
        uint256 leftShares;
        uint256 yieldAssets;
        uint256 exitSharePrice;
    }

    error InvalidTokenId();
    error UnstakeTransferError();
    error RedeemError();
    error InsufficientBalanceError(address);
    error TransferFailedError();
    error SharesOnQueueError();
    error IndexQueueError();
    error NothingToClaimError();
    error UnstakeRequestedError();
    error NotEnoughAssetsError();
    error InsufficientEth();
    error MaturityError();
    error OnlyPyeTokenHolders(uint8);
    error InvalidRedeemAmount();

    event InitializeBond(address pt, address yt, address providerVault, uint96 maturityDate);
    event EnterExitQueueEvent(address indexed receiver, uint256 shares, uint256 indexed exitTicket, uint256 exitTimestamp);
    event UnstakeEvent(address sender, uint256 newPositionTicket, uint256 claimedShares, uint256 claimedAssets, uint256 claimedYield);
    event PositionRedeemEvent(address sender, address token, uint256 redeemAssets);
    event ProtocolFeeEvent(address indexed receiver, uint256 indexed fee);
    event NewPositionEvent(address sender, uint256 amount, uint256 maturity, uint256 openShares, uint256 openSharePrice);
    // /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    // /*                     Actions                                */
    // /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    function initialize(address _validator, uint96 maturityDate_) external payable;
    function deposit(address _sender, uint256 _amount, bool _isPtLocked, bytes calldata _data) external payable;
    function requestUnstake(address sender) external returns (uint256 positionTicket);
    function unstake(address sender) external;
    function redeem(address sender, address token, uint256 shares) external;

    // /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    // /*                              Views                         */
    // /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    function router() external view returns (address);
    function pt() external view returns (address);
    function yt() external view returns (address);
    function exitRequest() external view returns (ExitRequest memory);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function vault() external view returns (address);
    function rewardsVault() external view returns (address);
    function getExitQueueIndex(uint256 ticket) external view returns (uint256 index);
    function getShares() external returns (uint256);
    function calculateExitedAssets() external view returns (uint256, uint256, uint256);
    function totalAssets() external returns (uint256 assets);
    function timeToMaturity() external view returns (uint256);
    function updateFeeRecipient(address feeRecipient, uint80 fee) external returns (bool);
    function totalShares() external view returns (uint256 assets);
    function pricePerShare(uint256 deposit_, uint256 _shares) external view returns (uint256);
    function getMatuirtyDate() external view returns (uint96);
    function capacity() external view returns (uint256);
    function isHarvestRequired() external view returns (bool);
}
