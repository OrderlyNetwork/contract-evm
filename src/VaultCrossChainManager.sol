// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./interface/IVault.sol";
import "./interface/IVaultCrossChainManager.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract VaultCrossChainManager is IVaultCrossChainManager, Ownable {
    IVault public vault;

    // construct
    constructor(address _vault) {
        vault = IVault(_vault);
    }

    // user withdraw USDC
    function withdraw(CrossChainMessageTypes.MessageV1 calldata message) public override onlyOwner {
        vault.withdraw(message.accountId, message.addr, message.tokenSymbol, message.tokenAmount);
    }
}
