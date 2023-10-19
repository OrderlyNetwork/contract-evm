// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../src/vaultSide/Vault.sol";
import "../../src/vaultSide/tUSDC.sol";

contract StartDeposit is Script {
    address constant userAddress = 0x4FDDB51ADe1fa66952de254bE7E1a84EEB153331;
    bytes32 constant userAccountId = 0x89bf2019fe60f13ec6c3f8de8c10156c2691ba5e743260dbcd81c2c66e87cba0;

    bytes32 constant USDC = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;
    bytes32 constant BROKER_HASH = 0x083098c593f395bea1de45dda552d9f14e8fcb0be3faaa7a1903c5477d7ba7fd;

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
