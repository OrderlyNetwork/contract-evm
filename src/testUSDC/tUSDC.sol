// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestUSDC is ERC20 {
    constructor() ERC20("TestUSDC", "tUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // everyone can direct mint usdc
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
