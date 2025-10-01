import {Test, console, Vm} from 'forge-std/Test.sol';

abstract contract BaseTest is Test {
    uint256 public constant ONE_YEAR_SECONDS = 31_536_000;
    uint256 public constant SIX_MONTH_SECONDS = 15_768_000;
    uint256 public constant THREE_MONTH_SECONDS = 7_884_000;

    function _createUser(string memory id, uint256 fundingAmt) internal returns (address) {
        Vm.Wallet memory wallet = vm.createWallet(id);
        vm.deal(wallet.addr, fundingAmt);
        return wallet.addr;
    }
}
