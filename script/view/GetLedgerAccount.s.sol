// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import "../../src/Ledger.sol";
import "../utils/BaseScript.s.sol";
import "../utils/ConfigHelper.s.sol";

contract GetLedgerAccount is BaseScript, ConfigHelper {
    function run() external {
        Envs memory envs = getEnvs();
        string memory env = envs.env;
        string memory network = envs.ledgerNetwork;
        console.log("env: ", env);
        console.log("network: ", network);

        LedgerDeployData memory config = getLedgerDeployData(env, network);
        address ledgerAddress = config.ledger;
        console.log("ledgerAddress: ", ledgerAddress);
        ILedger ledger = ILedger(ledgerAddress);
        bytes32 accountId = 0xb787ac72988077a8919892fecbbeea7473f350523d60ea89f17599c3910ece1e;
        bytes32[] memory data = new bytes32[](1);
        data[0] = accountId;

        AccountTypes.AccountSnapshot[] memory snaphots = ledger.batchGetUserLedger(data);
        for (uint256 i = 0; i < snaphots.length; i++) {
            AccountTypes.AccountSnapshot memory snapshot = snaphots[i];
            console2.log("\naccountId: ");
            console2.logBytes32(snapshot.accountId);
            console2.log("brokerHash: ");
            console2.logBytes32(snapshot.brokerHash);
            console2.log("userAddress: ", snapshot.userAddress);
            console2.log("lastWithdrawNonce: ", snapshot.lastWithdrawNonce);
            console2.log("lastPerpTradeId: ", snapshot.lastPerpTradeId);
            console2.log("lastEngineEventId: ", snapshot.lastEngineEventId);
            console2.log("lastDepositEventId: ", snapshot.lastDepositEventId);
            // tokenBalances
            for (uint256 j = 0; j < snapshot.tokenBalances.length; j++) {
                console2.log("\ntokenBalances: ");
                console2.logBytes32(snapshot.tokenBalances[j].tokenHash);
                console2.log("balance: ", snapshot.tokenBalances[j].balance);
                console2.log("frozenBalance: ", snapshot.tokenBalances[j].frozenBalance);
            }
            // perpPositions
            for (uint256 j = 0; j < snapshot.perpPositions.length; j++) {
                if (snapshot.perpPositions[j].positionQty == 0) continue;
                console2.log("\nperpPositions: ");
                console2.logBytes32(snapshot.perpPositions[j].symbolHash);
                console2.log("positionQty: ", snapshot.perpPositions[j].positionQty);
                console2.log("costPosition: ", snapshot.perpPositions[j].costPosition);
                console2.log("lastSumUnitaryFundings: ", snapshot.perpPositions[j].lastSumUnitaryFundings);
                console2.log("lastExecutedPrice: ", snapshot.perpPositions[j].lastExecutedPrice);
                console2.log("lastSettledPrice: ", snapshot.perpPositions[j].lastSettledPrice);
                console2.log("averageEntryPrice: ", snapshot.perpPositions[j].averageEntryPrice);
                console2.log("openingCost: ", snapshot.perpPositions[j].openingCost);
                console2.log("lastAdlPrice: ", snapshot.perpPositions[j].lastAdlPrice);
            }
        }
        console.log("get ledger account done");
    }
}
