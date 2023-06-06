// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "./types/PerpTypes.sol";

library VerifyEIP712 {
    function verifyWithdraw(address sender, address contractAddr, PerpTypes.WithdrawData calldata data) external pure {
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        bytes32 eip712DomainHash = keccak256(
            abi.encode(typeHash, keccak256(bytes("Orderly")), keccak256(bytes("1")), data.chainId, contractAddr)
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "Withdraw(string brokerId,uint256 chainId,address sender,address receiver,token string,uint256 amount,uint256 withdrawNonce,uint64 timestamp)"
                ),
                data.brokerId,
                data.chainId,
                data.sender,
                data.receiver,
                data.tokenSymbol,
                data.tokenAmount,
                data.withdrawNonce,
                data.timestamp
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));
        address signer = ecrecover(hash, data.v, data.r, data.s);
        require(signer == sender, "VerifyEIP712: invalid signature");
        require(signer != address(0), "VerifyEIP712: invalid signature");
    }
}
