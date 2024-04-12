// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/FeeManager.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainLedgerFeeManager is ConfigHelper, Test {
    uint256 mainnetFork;
    uint256 stagingFork;
    bytes32 constant PERP_BTC_USDC = 0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d; // PERP_BTC_USDC
    bytes32 constant PERP_ETH_USDC = 0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb; // PERP_ETH_USDC

    function setUp() public {
        // provent env not found error
        string memory RPC_URL_ORDERLYMAIN = vm.envString("RPC_URL_ORDERLYMAIN");
        string memory RPC_URL_ORDERLYOP = vm.envString("RPC_URL_ORDERLYOP");
        mainnetFork = vm.createFork(RPC_URL_ORDERLYMAIN);
        stagingFork = vm.createFork(RPC_URL_ORDERLYOP);
    }

    function test_onchain_feeManager_staging() external {
        vm.selectFork(stagingFork);
        string memory env = "staging";
        string memory network = "orderlyop";
        _test_onchain_feeManager(env, network);
    }

    function test_onchain_feeManager_mainnet() external {
        vm.selectFork(mainnetFork);
        string memory env = "mainnet";
        string memory network = "orderlymain";
        _test_onchain_feeManager(env, network);
    }

    function _test_onchain_feeManager(string memory env, string memory network) internal {
        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address feeManagerAddress = config.feeManager;
        console.log("feeManagerAddress: ", feeManagerAddress);
        IFeeManager feeManager = IFeeManager(feeManagerAddress);
        bytes32 withdrawFeeCollector = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.WithdrawFeeCollector);
        assertNotEq(withdrawFeeCollector, bytes32(0));
        bytes32 futuresFeeCollector = feeManager.getFeeCollector(IFeeManager.FeeCollectorType.FuturesFeeCollector);
        assertNotEq(futuresFeeCollector, bytes32(0));
    }
}
