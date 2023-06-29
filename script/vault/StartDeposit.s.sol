// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/Vault.sol";
import "../../src/testUSDC/tUSDC.sol";

contract StartDeposit is Script {
    address constant userAddress = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant userAccountId = 0x1794513e2fc05828d3205892dbef3c91eb7ffd6df62e0360acadd55650c9b672;

    bytes32 constant USDC = 0x61fc29e9a6b4b52b423e75ca44734454f94ea60ddff3dc47af01a2a646fe9572;
    bytes32 constant BROKER_HASH = 0xfb08c0b22085b07c3787ca55e02cc585a966b0799bfef3d32fc335d7107cedef;

    function run() external {
        uint256 userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address tUSDCAddress = vm.envAddress("TEST_USDC_ADDRESS");
        vm.startBroadcast(userPrivateKey);

        IVault vault = IVault(payable(vaultAddress));
        TestUSDC tUSDC = TestUSDC(payable(tUSDCAddress));
        tUSDC.mint(userAddress, 1000 * 1e6);
        tUSDC.approve(vaultAddress, 1000 * 1e6);
        vault.deposit(
            VaultTypes.VaultDepositFE({
                accountId: userAccountId,
                tokenHash: USDC,
                brokerHash: BROKER_HASH,
                tokenAmount: 1000 * 1e6
            })
        );

        vm.stopBroadcast();
    }
}
