// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {VaultTypes} from "./types/VaultTypes.sol";

library DelegateSwapSignature {

    function validateDelegateSwapSignature(
        address expectedSigner,
        VaultTypes.DelegateSwap calldata data
    ) internal view returns (bool) {
        bytes memory encoded = abi.encode(
            data.tradeId,
            block.chainid,
            data.inTokenHash,
            data.inTokenAmount,
            data.to,
            data.value,
            data.swapCalldata
        );

        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(encoded));
        address recoveredAddress = ECDSA.recover(digest, data.v, data.r, data.s);
        return recoveredAddress == expectedSigner;
    }
}