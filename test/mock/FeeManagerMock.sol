// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../src/interface/IFeeManager.sol";
import "../../src/LedgerComponent.sol";

contract FeeManagerMock is IFeeManager, LedgerComponent {
    constructor() {
        _disableInitializers();
    }

    function initialize() public override initializer {
        __Ownable_init();
    }

    function getOperatorGasFeeBalance(bytes32 tokenHash) external override returns (uint128) {}

    function setOperatorGasFeeBalance(bytes32 tokenHash, uint128 amount) external override {}

    function getFeeAmount() external override returns (uint128) {}

    function changeFeeAmount(uint128 amount) external override {}

    function getFeeCollector(FeeCollectorType feeCollectorType) external override returns (bytes32) {}

    function changeFeeCollector(FeeCollectorType feeCollectorType, bytes32 _newCollector) external override {}
}
