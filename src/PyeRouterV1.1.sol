// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

import {BeaconProxy} from 'openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol';
import {IBond} from './interfaces/IBond.sol';
import {IPyeRouterV1} from './interfaces/IPyeRouterV1.sol';
import {IEthPrivVault} from './adapters/StakeWise/interfaces/IEthPrivVault.sol';

contract PyeRouterV1 is IPyeRouterV1 {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string public constant name = 'PyeRouter';
    string public constant version = '1';
    uint256 public immutable MAX_BPS = 10_000;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        STORAGE                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    address public admin;
    address public feeRecipient;
    address public defaultBeacon;
    uint256 public mintFee;
    uint256 public redemptionFee;

    mapping(bytes32 bondId => BondStorage bond) public bonds;
    mapping(address => bool) public isValidatorVault;
    address[] public validators;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                CONSTRUCTOR, FALLBACKS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    constructor(address _feeRecipient, address _beacon, uint96 _mintFee, uint96 _redemptionFee, address[] memory _validatorVaults) {
        admin = msg.sender;
        feeRecipient = _checkAddressZero(_feeRecipient);
        defaultBeacon = _checkAddressZero(_beacon);
        mintFee = _validateFee(_mintFee);
        redemptionFee = _validateFee(_redemptionFee);

        uint256 validatorsLength = _validatorVaults.length;
        validators = new address[](validatorsLength);
        for (uint256 i = 0; i < validatorsLength;) {
            if (_validatorVaults[i] == address(0)) revert ZeroAddressNotAllowed();
            isValidatorVault[_validatorVaults[i]] = true;
            validators[i] = _validatorVaults[i];
            unchecked {
                ++i;
            }
        }
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       MODIFIERS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   PUBLIC FUNCTIONS                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function getBondId(address _validatorVault, uint96 _maturity) public pure returns (bytes32 bondId) {
        bondId = keccak256(abi.encodePacked(_validatorVault, _maturity));
    }

    function createBond(address _validatorVault, uint96 _maturity) public returns (BondStorage memory bondStorage) {
        if (!isValidatorVault[_validatorVault]) revert InvalidVaultError();
        if (defaultBeacon == address(0)) revert DefaultBeaconNotSet();

        bytes32 bondId = getBondId(_validatorVault, _maturity);

        if (bonds[bondId].bondAddress != address(0)) {
            revert BondAlreadyExists();
        }

        address bondAddress = address(
            new BeaconProxy(
                defaultBeacon, // beacon contract of specific provider
                abi.encodeWithSignature('initialize(address,uint96)', _validatorVault, _maturity)
            )
        );

        // router will have to be access manager of validator vault, else if its not private vault - no wl
        if (IEthPrivVault(_validatorVault).whitelister() == address(this)) {
            IEthPrivVault(_validatorVault).updateWhitelist(bondAddress, true);
        }

        IBond bond = IBond(bondAddress);

        bondStorage = BondStorage(defaultBeacon, bondAddress, ptAddress, ytAddress, _validatorVault, _maturity);
        bonds[bondId] = bondStorage;

        address ptAddress = bond.pt();
        address ytAddress = bond.yt();

        emit BondCreated(bondStorage);
    }

    function deposit(address _sender, uint256 _amount, address _validatorVault, uint96 _maturity, bool isPtLocked, bytes memory _data) external payable override returns (BondStorage memory bond) {
        if (msg.value < _amount) revert InsufficientEth();
        bytes32 bondId = getBondId(_validatorVault, _maturity);
        bond = bonds[bondId];
        /// does bondId exist, if yes deposit, otherwise create and then deposit
        if (bond.bondAddress == address(0)) {
            bond = createBond(_validatorVault, _maturity);
            IBond(bond.bondAddress).deposit{value: msg.value}(_sender, _amount, isPtLocked, _data);
        } else {
            IBond(bond.bondAddress).deposit{value: msg.value}(_sender, _amount, isPtLocked, _data);
        }

        emit DepositEvent(_sender, _amount, isPtLocked, _validatorVault, _maturity, bond.bondAddress);
    }

    function requestUnstake(address _validatorVault, uint96 _maturity) external override {
        bytes32 bondId = getBondId(_validatorVault, _maturity);
        BondStorage memory bond = bonds[bondId];

        // check bond existance, caller to be PYE holder and maturity
        _verifyBondStatus(bond);

        // request bond to enter exit queue, SWv3 does not return an exit ticket
        IBond(bond.bondAddress).requestUnstake(msg.sender);

        emit UnstakeRequestedEvent(msg.sender, _validatorVault, _maturity);
    }

    function unstake(address _validatorVault, uint96 _maturity) external override {
        bytes32 bondId = getBondId(_validatorVault, _maturity);
        BondStorage memory bond = bonds[bondId];

        // check bond existance, caller to be PYE holder and maturity
        _verifyBondStatus(bond);

        // request funds from eth vault to bond
        IBond(bond.bondAddress).unstake(msg.sender);
        emit UnstakeEvent(msg.sender, _validatorVault, _maturity);
    }

    function redeem(address _redeemToken, uint256 _amount, address _validatorVault, uint96 _maturity) external override {
        bytes32 bondId = getBondId(_validatorVault, _maturity);
        BondStorage memory bond = bonds[bondId];

        // check bond existance, caller to be PYE holder and maturity
        _verifyBondStatus(bond);

        // withdraw
        IBond(bond.bondAddress).redeem(msg.sender, _redeemToken, _amount);
        emit PositionRedeemEvent(msg.sender, _redeemToken, _amount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    EXTERNAL VIEWS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function previewShares(address _validatorVault, uint96 _maturity, uint256 _shares) external view returns (uint256 _assets) {
        bytes32 bondId = getBondId(_validatorVault, _maturity);
        BondStorage memory bond = bonds[bondId];
        if (bond.bondAddress == address(0)) revert BondDoesNotExist();
        _assets = IBond(bond.bondAddress).convertToAssets(_shares);
    }

    function validatorsCount() external view returns (uint256) {
        return validators.length;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 PERMISSIONED FUNCTIONS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function updateDefaultBeacon(address _newBeacon) external onlyAdmin {
        address previousBeacon = defaultBeacon;
        defaultBeacon = _newBeacon;
        emit DefaultBeaconUpdated(previousBeacon, _newBeacon);
    }

    function addValidatorVault(address _validatorVault) external onlyAdmin {
        require(!isValidatorVault[_validatorVault], 'Validator vault already exists');
        isValidatorVault[_validatorVault] = true;
        validators.push(_validatorVault);
        emit ValidatorVaultAdded(_validatorVault);
    }

    function removeValidatorVault(address _validatorVault) external onlyAdmin {
        require(isValidatorVault[_validatorVault], 'Validator vault does not exist');
        delete isValidatorVault[_validatorVault];
        emit ValidatorVaultRemoved(_validatorVault);
    }

    function removeValidatorVault(uint256 _validatorIndex) external onlyAdmin {
        require(validators[_validatorIndex] != address(0), 'Validator vault does not exist');
        emit ValidatorVaultRemoved(validators[_validatorIndex]);
        delete validators[_validatorIndex];
    }

    function updateMintFee(uint256 _newFee) external onlyAdmin {
        uint256 _oldFeeBPS = redemptionFee;
        mintFee = _newFee;

        emit MintFeeEdited(_oldFeeBPS, _newFee);
    }

    function updateRedemptionFee(uint256 _newFee) external onlyAdmin {
        uint256 _oldFeeBPS = redemptionFee;
        redemptionFee = _newFee;

        emit MintFeeEdited(_oldFeeBPS, _newFee);
    }

    function editFeeRecipient(address _newFeeRecipient) external onlyAdmin {
        require(_newFeeRecipient != address(0), 'Address must not be 0');

        feeRecipient = _newFeeRecipient;

        emit FeeRecipientChanged(_newFeeRecipient);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  INTERNAL FUNCTIONS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _verifyBondStatus(BondStorage memory _bond) internal view {
        if (_bond.bondAddress == address(0)) revert BondDoesNotExist();
        _verifyPyeHolders(_bond.ptAddress, _bond.ytAddress);
        _verifyMaturity(_bond.maturity);
    }

    function _verifyPyeHolders(address _pt, address _yt) internal view {
        if (IERC20(_pt).balanceOf(msg.sender) < 1 && IERC20(_yt).balanceOf(msg.sender) < 1) revert OnlyPyeHoldersError();
    }

    function _verifyMaturity(uint96 _maturity) internal view {
        if (_maturity > block.timestamp) revert MaturityError();
    }

    function _validateFee(uint256 _fee) internal pure returns (uint256) {
        if (_fee > 5000) revert InvalidFee(); // 50 BPS
        return _fee;
    }

    function _isValidMaturity(uint96 _maturity) internal view returns (bool) {
        return _maturity > block.timestamp + 3 days;
    }

    function _checkAddressZero(address _address) internal pure returns (address) {
        if (_address == address(0)) revert ZeroAddressNotAllowed();
        return _address;
    }
}
