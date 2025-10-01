// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPyeRouterV1 {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    STRUCTS, ERROR AND EVENTS                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct BondStorage {
        address beacon;
        address bondAddress;
        address ptAddress;
        address ytAddress;
        address validatorVault;
        uint96 maturity;
    }

    // custom errors
    error OnlyAdmin();
    error BondAlreadyExists();
    error ZeroAddressNotAllowed();
    error BondDoesNotExist();
    error MaturityError();
    error InvalidFee();
    error OnlyPyeHoldersError();
    error InvalidVaultError();
    error InsufficientEth();
    error DefaultBeaconNotSet();

    // events
    event BondCreated(BondStorage bondStorage);
    event FeeRecipientChanged(address indexed previousRecipient);
    event MintFeeEdited(uint256 previousFee, uint256 newFee);
    event ValidatorVaultRemoved(address indexed validatorVault);
    event DefaultBeaconUpdated(address indexed previousBeacon, address indexed newBeacon);
    event ValidatorVaultAdded(address indexed validatorVault);
    event DepositEvent(address indexed sender, uint256 amount, bool isPtLocked, address validatorVault, uint96 maturity, address bondAddress);
    event UnstakeRequestedEvent(address indexed sender, address indexed validatorVault, uint96 maturity);
    event UnstakeEvent(address sender, address validatorVault, uint96 maturity);
    event PositionRedeemEvent(address indexed sender, address token, uint256 redeemAssets);

    function getBondId(address _validator, uint96 _maturityDate) external returns (bytes32 _bondId);
    function deposit(address _sender, uint256 _amount, address _validatorVault, uint96 _maturity, bool isPtLocked, bytes memory _data) external payable returns (BondStorage memory bond);
    function requestUnstake(address _validatorVault, uint96 _maturity) external;
    function unstake(address _validatorVault, uint96 _maturity) external;
    function redeem(address _redeemToken, uint256 _amount, address _validatorVault, uint96 _maturity) external;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    External Views                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function previewShares(address _validatorVault, uint96 _maturity, uint256 _shares) external view returns (uint256 _assets);
}
