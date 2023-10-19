// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/VaultTypes.sol";

interface IVaultCrossChainManager {
    /**
     * @notice withdraw from ledger
     * @param _withdraw withdraw data
     */
    function withdraw(VaultTypes.VaultWithdraw memory _withdraw) external;

    /**
     * @notice deposit to vault
     * @param _data deposit data
     */
    function deposit(VaultTypes.VaultDeposit memory _data) external payable;

    /**
     * @notice deposit to vault with native fee
     * @param _data deposit data
     * @param _amount fee amount
     */
    function depositWithFee(VaultTypes.VaultDeposit memory _data, uint256 _amount) external payable;

    /**
     * @notice get deposit fee
     * @param _data deposit data
     * @return fee
     */
    function getDepositFee(VaultTypes.VaultDeposit memory _data) external view returns (uint256);

    /**
     * @notice set Vault
     * @param _vault vault address
     */
    function setVault(address _vault) external;

    /**
     * @notice set crossChainRelay
     * @param _crossChainRelay crossChainRelay address
     */
    function setCrossChainRelay(address _crossChainRelay) external;
}
