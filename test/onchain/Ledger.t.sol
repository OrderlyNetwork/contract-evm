// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/Ledger.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainLedger is ConfigHelper, Test {
    uint256 mainnetFork;
    uint256 stagingFork;
    bytes32 constant ACCOUNT_ID_1 = 0xa11ce00000000000000000000000000000000000000000000000000000000000;
    bytes32 constant ACCOUNT_ID_2 = 0xb0b0000000000000000000000000000000000000000000000000000000000000;

    function setUp() public {
        // provent env not found error
        string memory RPC_URL_ORDERLYMAIN = vm.envString("RPC_URL_ORDERLYMAIN");
        string memory RPC_URL_ORDERLYOP = vm.envString("RPC_URL_ORDERLYOP");
        mainnetFork = vm.createFork(RPC_URL_ORDERLYMAIN);
        stagingFork = vm.createFork(RPC_URL_ORDERLYOP);
    }

    function test_onchain_ledger_staging() external {
        vm.selectFork(stagingFork);
        string memory env = "staging";
        string memory network = "orderlyop";
        _test_onchain_ledger(env, network);
    }

    function test_onchain_ledger_mainnet() external {
        vm.selectFork(mainnetFork);
        string memory env = "mainnet";
        string memory network = "orderlymain";
        _test_onchain_ledger(env, network);
    }

    function _test_onchain_ledger(string memory env, string memory network) internal {
        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address ledgerAddress = config.ledger;
        console.log("ledgerAddress: ", ledgerAddress);
        ILedger ledger = ILedger(ledgerAddress);
        bytes32[] memory accountIds = new bytes32[](2);
        accountIds[0] = ACCOUNT_ID_1;
        accountIds[1] = ACCOUNT_ID_2;
        AccountTypes.AccountSnapshot[] memory accountSnapshots = ledger.batchGetUserLedger(accountIds);
        console2.log("accountSnapshots length: ", accountSnapshots.length);
        assertEq(accountSnapshots.length, 2);
        assertEq(accountSnapshots[0].accountId, ACCOUNT_ID_1);
        assertEq(accountSnapshots[1].accountId, ACCOUNT_ID_2);
    }
}
