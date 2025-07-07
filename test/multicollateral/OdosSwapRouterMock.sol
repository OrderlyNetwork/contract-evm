// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IOdosRouterV2 } from "./IOdosRouterV2.sol";

/**
 * @title OdosRouterV2Mock
 * @notice A lightweight mock that satisfies the ABI of the real OdosRouterV2 so that
 *         front‑end integrations and unit tests can compile and run without touching
 *         main‑net contracts. All state‑changing functions perform minimal bookkeeping
 *         (e.g. recording fees, emitting events) and then return deterministic dummy
 *         values that make test assertions easy.
 *
 *         ⚠️  DO NOT use this contract in production – it has NO economic guarantees.
 */
contract OdosSwapRouterMock is IOdosRouterV2 {

    uint256 public constant FEE_DENOM = 10_000; // basis‑points denominator
    uint256 public constant REFERRAL_WITH_FEE_THRESHOLD = 1 ether; // arbitrary


    address public owner;
    uint256 public swapMultiFee; // flat fee for swapMulti*

    address[] public addressList;
    mapping(uint32 => Referral) public referralLookup;

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_ADDR");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function setSwapMultiFee(uint256 _swapMultiFee) external onlyOwner {
        swapMultiFee = _swapMultiFee;
    }

    function writeAddressList(address[] calldata addresses_) external onlyOwner {
        addressList = addresses_;
    }

    function registerReferralCode(
        uint32  _referralCode,
        uint64  _referralFee,
        address _beneficiary
    ) external {
        Referral storage info = referralLookup[_referralCode];
        require(!info.registered, "ALREADY_REGISTERED");
        info.referralFee = _referralFee;
        info.beneficiary = _beneficiary;
        info.registered  = true;
    }

    function swap(
        swapTokenInfo calldata tokenInfo,
        bytes calldata /* pathDefinition */,
        address /* executor */,
        uint32 referralCode
    ) external payable returns (uint256 amountOut) {
        // For the mock we simply echo back the quoted amount.
        amountOut = tokenInfo.outputQuote;
        emit Swap(
            msg.sender,
            tokenInfo.inputAmount,
            tokenInfo.inputToken,
            amountOut,
            tokenInfo.outputToken,
            // int256(int128(amountOut) - int128(tokenInfo.outputMin)), // mock slippage
            0,
            referralCode
        );
    }

    // Compact variant just forwards to swap() with zeroed‑out placeholders.
    function swapCompact() external payable returns (uint256) {
        return 0;
    }

    function swapCompactRevert() external payable returns (uint256) {
        revert("OdosSwapRouterMock: swapCompactRevert");
    }

    function swapPermit2(
        permit2Info calldata /* permit2 */,
        swapTokenInfo calldata tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external returns (uint256) {
        // return swap(tokenInfo, pathDefinition, executor, referralCode);
    }

    /* ────────────────────────────────────────────────────────────────────────────────
                                    MULTI‑SWAPS
    ─────────────────────────────────────────────────────────────────────────────── */

    function _mockAmountsOut(outputTokenInfo[] calldata outputs)
        internal
        pure
        returns (uint256[] memory outAmounts)
    {
        outAmounts = new uint256[](outputs.length);
        for (uint256 i; i < outputs.length; ++i) {
            outAmounts[i] = outputs[i].relativeValue;
        }
    }

    function swapMulti(
        inputTokenInfo[] calldata  inputs,
        outputTokenInfo[] calldata outputs,
        uint256 /* valueOutMin */,
        bytes calldata /* pathDefinition */,
        address /* executor */,
        uint32 referralCode
    ) external payable returns (uint256[] memory amountsOut) {
        amountsOut = _mockAmountsOut(outputs);

        // Build arrays for event that match the ABI expectation.
        uint256 inLen  = inputs.length;
        uint256 outLen = outputs.length;

        uint256[] memory amountsIn = new uint256[](inLen);
        address[] memory tokensIn  = new address[](inLen);
        for (uint256 i; i < inLen; ++i) {
            amountsIn[i] = inputs[i].amountIn;
            tokensIn[i]  = inputs[i].tokenAddress;
        }

        address[] memory tokensOut = new address[](outLen);
        for (uint256 i; i < outLen; ++i) {
            tokensOut[i] = outputs[i].tokenAddress;
        }

        emit SwapMulti(msg.sender, amountsIn, tokensIn, amountsOut, tokensOut, referralCode);
    }

    function swapMultiCompact() external payable returns (uint256[] memory) {
        uint256[] memory dummy;
        return dummy;
    }

    function swapMultiPermit2(
        permit2Info calldata /* permit2 */,
        inputTokenInfo[] calldata  inputs,
        outputTokenInfo[] calldata outputs,
        uint256 valueOutMin,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external payable returns (uint256[] memory) {
        // return swapMulti(inputs, outputs, valueOutMin, pathDefinition, executor, referralCode);
    }


    function swapRouterFunds(
        inputTokenInfo[] calldata  inputs,
        outputTokenInfo[] calldata outputs,
        uint256 valueOutMin,
        bytes calldata pathDefinition,
        address executor
    ) external returns (uint256[] memory) {
        // return swapMulti(inputs, outputs, valueOutMin, pathDefinition, executor, 0);
    }

    /* ────────────────────────────────────────────────────────────────────────────────
                                  ROUTER FUND TRANSFERS
    ─────────────────────────────────────────────────────────────────────────────── */

    function transferRouterFunds(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address dest
    ) external onlyOwner {
        require(tokens.length == amounts.length, "LEN_MISMATCH");
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == address(0)) {
                (bool ok, ) = dest.call{value: amounts[i]}("");
                require(ok, "ETH_TRANSFER_FAIL");
            } else {
                // solhint-disable-next-line avoid-low-level-calls
                (bool ok, ) = tokens[i].call(abi.encodeWithSignature("transfer(address,uint256)", dest, amounts[i]));
                require(ok, "ERC20_TRANSFER_FAIL");
            }
        }
    }

    /* ────────────────────────────────────────────────────────────────────────────────
                                   FALLBACK / RECEIVE
    ─────────────────────────────────────────────────────────────────────────────── */

    receive() external payable {}
}
