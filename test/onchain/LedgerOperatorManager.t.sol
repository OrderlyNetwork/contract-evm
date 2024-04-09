// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/OperatorManager.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainLedgerOperatorManager is ConfigHelper, Test {
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

    function test_onchain_operatorManager_staging() external {
        vm.selectFork(stagingFork);
        string memory env = "staging";
        string memory network = "orderlyop";
        _test_onchain_operatorManager(env, network);
    }

    function test_onchain_operatorManager_mainnet() external {
        vm.selectFork(mainnetFork);
        string memory env = "mainnet";
        string memory network = "orderlymain";
        _test_onchain_operatorManager(env, network);
    }

    function _test_onchain_operatorManager(string memory env, string memory network) internal {
        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address operatorManagerAddress = config.operatorManager;
        console.log("operatorManagerAddress: ", operatorManagerAddress);
        OperatorManager operatorManager = OperatorManager(operatorManagerAddress);
        assertGt(operatorManager.eventUploadBatchId(), 0);
        assertGt(operatorManager.futuresUploadBatchId(), 0);
        assertGt(operatorManager.lastOperatorInteraction(), 0);
        assertNotEq(operatorManager.engineSpotTradeUploadAddress(), address(0));
        assertNotEq(operatorManager.enginePerpTradeUploadAddress(), address(0));
        assertNotEq(operatorManager.engineEventUploadAddress(), address(0));
        assertNotEq(operatorManager.engineMarketUploadAddress(), address(0));
        assertNotEq(operatorManager.engineRebalanceUploadAddress(), address(0));
    }
}
