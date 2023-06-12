// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./types/EventTypes.sol";

library VerifyEIP712 {
    function verifyWithdraw(address sender, address contractAddr, EventTypes.WithdrawData calldata data) external pure returns(bool) {
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        bytes32 eip712DomainHash = keccak256(
            abi.encode(typeHash, keccak256(bytes("Orderly")), keccak256(bytes("1")), data.chainId, contractAddr)
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "Withdraw(string brokerId,uint256 chainId,address receiver,token string,uint256 amount,uint64 withdrawNonce,uint64 timestamp)"
                ),
                data.brokerId,
                data.chainId,
                data.receiver,
                data.tokenSymbol,
                data.tokenAmount,
                data.withdrawNonce,
                data.timestamp
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));
        address signer = ecrecover(hash, data.v, data.r, data.s);
        return signer == sender && signer != address(0);
    }
}
