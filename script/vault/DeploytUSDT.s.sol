// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../../test/mock/ERC20Mock.sol";

contract UpgradeVault is Script {
    function run() external {
        uint256 orderlyPrivateKey = vm.envUint("PK");

        vm.startBroadcast(orderlyPrivateKey);

        ERC20Mock usdt = new ERC20Mock("tUSDT", "tUSDT", 8);

        console.log("tUSDT deployed at:", address(usdt));

        vm.stopBroadcast();
    }
}
