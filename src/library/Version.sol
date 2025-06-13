// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Version {
    function version() external pure returns (string memory) {
        return "0.6.1.alpha.3";
    }
}