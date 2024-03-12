// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/zip/OperatorManagerZip.sol";
import "../../script/utils/ConfigHelper.s.sol";

contract OnchainLedgerOperatorManagerZip is ConfigHelper, Test {
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

    function test_onchain_operatorManagerZip_staging() external {
        vm.selectFork(stagingFork);
        string memory env = "staging";
        string memory network = "orderlyop";
        _test_onchain_operatorManagerZip(env, network);
    }

    function test_onchain_operatorManagerZip_mainnet() external {
        vm.selectFork(mainnetFork);
        string memory env = "mainnet";
        string memory network = "orderlymain";
        _test_onchain_operatorManagerZip(env, network);
    }

    function _test_onchain_operatorManagerZip(string memory env, string memory network) internal {
        ZipDeployData memory config = getZipDeployData(env, network);
        address zipAddress = config.zip;
        console.log("Zip address: ", zipAddress);
        OperatorManagerZip operatorManagerZip = OperatorManagerZip(zipAddress);
        address zipOperatorAddress = operatorManagerZip.zipOperatorAddress();
        assertNotEq(zipOperatorAddress, address(0));
        assertEq(
            operatorManagerZip.symbolId2Hash(1),
            bytes32(0x5a8133e52befca724670dbf2cade550c522c2410dd5b1189df675e99388f509d)
        );
        assertEq(
            operatorManagerZip.symbolId2Hash(2),
            bytes32(0x7e83089239db756ee233fa8972addfea16ae653db0f692e4851aed546b21caeb)
        );
        assertEq(
            operatorManagerZip.symbolId2Hash(3),
            bytes32(0x2f1991e99a4e22a9e95ff1b67aee336b4047dc47612e36674fa23eb8c6017f2e)
        );
        assertEq(
            operatorManagerZip.symbolId2Hash(4),
            bytes32(0x3e5bb1a69a9094f1b2ccad4f39a7d70e2a29f08c2c0eac87b970ea650ac12ec2)
        );
        assertEq(
            operatorManagerZip.symbolId2Hash(5),
            bytes32(0xb5ec44c9e46c5ae2fa0473eb8c466c97ec83dd5f4eddf66f31e83b512cff503c)
        );
    }
}
