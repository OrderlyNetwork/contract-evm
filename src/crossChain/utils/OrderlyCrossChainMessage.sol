// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// List of methods that can be called cross-chain
enum CrossChainMethod {
    LayerZero
}

// Library to handle the conversion of the message structure to bytes array and vice versa
library OrderlyCrossChainMessage {
    // The structure of the message
    struct MessageV1 {
        uint8 version; // Version number of the message structure
        address userAddress; // User address
        uint256 srcChainId; // Source blockchain ID
        uint256 dstChainId; // Target blockchain ID
        string method; // CrossChainMethod enum converted to string
        bytes32 accountId; // Account address converted to string
        bytes32 tokenSymbol; // Token symbol for transfer
        uint256 tokenAmount; // Amount of token for transfer
    }

    /**
     * @dev Convert a message to a bytes array
     * @param self The MessageV1 struct to be converted
     * @return data The converted bytes array
     */
    function toArray(
        MessageV1 memory self
    ) internal pure returns (bytes[] memory) {
        bytes[] memory data = new bytes[](8);
        data[0] = abi.encodePacked(self.version);
        data[1] = abi.encodePacked(self.userAddress);
        data[2] = abi.encodePacked(self.srcChainId);
        data[3] = abi.encodePacked(self.dstChainId);
        data[4] = abi.encodePacked(self.method);
        data[5] = abi.encodePacked(self.accountId);
        data[6] = abi.encodePacked(self.tokenSymbol);
        data[7] = abi.encodePacked(self.tokenAmount);
        return data;
    }

    /**
     * @dev Convert a bytes array to a message
     * @param data The bytes array to be converted
     * @return message The converted MessageV1 struct
     */
    function arrayToMsg(
        bytes[] memory data
    ) internal pure returns (MessageV1 memory) {
        MessageV1 memory message;
        message.version = uint8(bytes1(data[0]));
        message.userAddress = address(bytes20(data[1]));
        message.srcChainId = uint256(bytes32(data[1]));
        message.dstChainId = uint256(bytes32(data[2]));
        message.method = string(data[3]);
        message.accountId = bytes32(data[4]);
        message.tokenSymbol = bytes(data[5]);
        message.tokenAmount = uint256(bytes32(data[6]));
        return message;
    }

    /**
     * @dev Pack a bytes array into a single bytes string
     * @param data The bytes array to be packed
     * @return payload The packed bytes string
     */
    function encodePacked(
        bytes[] memory data
    ) internal pure returns (bytes memory) {
        bytes memory payload;
        for (uint i = 0; i < data.length; i++) {
            payload = abi.encodePacked(payload, data[i].length);
            payload = abi.encodePacked(payload, data[i]);
        }
        return payload;
    }

    /**
     * @dev Unpack a single bytes string into a bytes array
     * @param payload The bytes string to be unpacked
     * @return data The unpacked bytes array
     */
    function decodePacked(
        bytes memory payload
    ) internal pure returns (bytes[] memory) {
        bytes[] memory data;
        uint offset = 0;

        while (offset < payload.length) {
            // Decode the length of the next data piece
            uint dataLength;
            uint loadOffset = offset + 32;
            assembly {
                dataLength := mload(add(payload, loadOffset))
            }
            offset += 32; // Skip the data length

            // Get the next data piece
            bytes memory dataPiece = new bytes(dataLength);
            for (uint i = 0; i < dataLength; i++) {
                dataPiece[i] = payload[offset + i];
            }
            offset += dataLength; // Skip the data piece

            // Extend the data array
            bytes[] memory temp = new bytes[](data.length + 1);
            for (uint i = 0; i < data.length; i++) {
                temp[i] = data[i];
            }
            temp[data.length] = dataPiece;
            data = temp;
        }

        return data;
    }
}
