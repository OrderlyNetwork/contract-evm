// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library OperatorTypes {
    enum OperatorActionData {
        None,
        UserRegister,
        UserDeposit,
        FuturesTradeUpload,
        EventUpload,
        PerpMarketInfo
    }
}
