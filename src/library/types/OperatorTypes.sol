// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library OperatorTypes {
    enum OperatorActionData {
        None,
        UserRegister,
        FuturesTradeUpload,
        EventUpload,
        PerpMarketInfo
    }

    enum CrossChainOperatorActionData {
        None,
        UserDeposit,
        UserEmergencyWithdraw
    }
}
