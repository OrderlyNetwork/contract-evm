// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/MarketManager.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainLedgerMarketManager is ConfigHelper, Test {
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

    function test_onchain_marketManager_staging() external {
        vm.selectFork(stagingFork);
        string memory env = "staging";
        string memory network = "orderlyop";
        _test_onchain_marketManager(env, network);
    }

    function test_onchain_marketManager_mainnet() external {
        vm.selectFork(mainnetFork);
        string memory env = "mainnet";
        string memory network = "orderlymain";
        _test_onchain_marketManager(env, network);
    }

    function _test_onchain_marketManager(string memory env, string memory network) internal {
        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address marketManagerAddress = config.marketManager;
        console.log("marketManagerAddress: ", marketManagerAddress);
        IMarketManager marketManager = IMarketManager(marketManagerAddress);
        MarketTypes.PerpMarketCfg memory cfg1 = marketManager.getPerpMarketCfg(PERP_BTC_USDC);
        assertGt(cfg1.markPrice, 0);
        assertGt(cfg1.indexPriceOrderly, 0);
        assertNotEq(cfg1.sumUnitaryFundings, 0);
        assertGt(cfg1.lastMarkPriceUpdated, 0);
        assertGt(cfg1.lastFundingUpdated, 0);
        MarketTypes.PerpMarketCfg memory cfg2 = marketManager.getPerpMarketCfg(PERP_ETH_USDC);
        assertGt(cfg2.markPrice, 0);
        assertGt(cfg2.indexPriceOrderly, 0);
        assertNotEq(cfg2.sumUnitaryFundings, 0);
        assertGt(cfg2.lastMarkPriceUpdated, 0);
        assertGt(cfg2.lastFundingUpdated, 0);
    }
}
