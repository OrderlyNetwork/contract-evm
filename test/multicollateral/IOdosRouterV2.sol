// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOdosRouterV2
/// @notice Solidity interface auto‑generated from the published OdosRouterV2 ABI.
///         Import this in your contracts or tests to interact with any OdosRouterV2‑compatible router.
interface IOdosRouterV2 {
    /* ────────────────────────────────────────────────────────────────────────────
                                          STRUCTS
    ─────────────────────────────────────────────────────────────────────────── */

    struct inputTokenInfo {
        address tokenAddress;
        uint256 amountIn;
        address receiver;
    }

    struct outputTokenInfo {
        address tokenAddress;
        uint256 relativeValue;
        address receiver;
    }

    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    struct permit2Info {
        address contractAddress;
        uint256 nonce;
        uint256 deadline;
        bytes   signature;
    }

    /// @dev Metadata stored against each referralCode inside `referralLookup`.
    struct Referral {
        uint64  referralFee;  // fee in basis‑points (1 bps = 0.01%)
        address beneficiary;  // recipient of the referral rebate
        bool    registered;   // true once `registerReferralCode()` succeeds
    }

    /* ────────────────────────────────────────────────────────────────────────────
                                            EVENTS
    ─────────────────────────────────────────────────────────────────────────── */

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event Swap(
        address sender,
        uint256 inputAmount,
        address inputToken,
        uint256 amountOut,
        address outputToken,
        int256  slippage,
        uint32  referralCode
    );

    event SwapMulti(
        address sender,
        uint256[] amountsIn,
        address[] tokensIn,
        uint256[] amountsOut,
        address[] tokensOut,
        uint32   referralCode
    );

    /* ────────────────────────────────────────────────────────────────────────────
                                           CONSTANTS
    ─────────────────────────────────────────────────────────────────────────── */

    function FEE_DENOM() external view returns (uint256);
    function REFERRAL_WITH_FEE_THRESHOLD() external view returns (uint256);

    /* ────────────────────────────────────────────────────────────────────────────
                                           GETTERS
    ─────────────────────────────────────────────────────────────────────────── */

    function owner() external view returns (address);
    function swapMultiFee() external view returns (uint256);
    function addressList(uint256) external view returns (address);
    function referralLookup(uint32)
        external
        view
        returns (uint64 referralFee, address beneficiary, bool registered);

    /* ────────────────────────────────────────────────────────────────────────────
                                           ADMIN
    ─────────────────────────────────────────────────────────────────────────── */

    function transferOwnership(address newOwner) external;
    function renounceOwnership() external;
    function setSwapMultiFee(uint256 _swapMultiFee) external;
    function writeAddressList(address[] calldata addresses_) external;

    /* ────────────────────────────────────────────────────────────────────────────
                                          REFERRAL
    ─────────────────────────────────────────────────────────────────────────── */

    function registerReferralCode(
        uint32  _referralCode,
        uint64  _referralFee,
        address _beneficiary
    ) external;

    /* ────────────────────────────────────────────────────────────────────────────
                                            SWAPS
    ─────────────────────────────────────────────────────────────────────────── */

    function swap(
        swapTokenInfo calldata tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external payable returns (uint256 amountOut);

    function swapCompact() external payable returns (uint256 amountOut);

    function swapPermit2(
        permit2Info calldata permit2,
        swapTokenInfo calldata tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external returns (uint256 amountOut);

    /* ────────────────────────────────────────────────────────────────────────────
                                         MULTI‑SWAPS
    ─────────────────────────────────────────────────────────────────────────── */

    function swapMulti(
        inputTokenInfo[] calldata inputs,
        outputTokenInfo[] calldata outputs,
        uint256 valueOutMin,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external payable returns (uint256[] memory amountsOut);

    function swapMultiCompact() external payable returns (uint256[] memory amountsOut);

    function swapMultiPermit2(
        permit2Info calldata permit2,
        inputTokenInfo[] calldata inputs,
        outputTokenInfo[] calldata outputs,
        uint256 valueOutMin,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external payable returns (uint256[] memory amountsOut);

    function swapRouterFunds(
        inputTokenInfo[] calldata inputs,
        outputTokenInfo[] calldata outputs,
        uint256 valueOutMin,
        bytes calldata pathDefinition,
        address executor
    ) external returns (uint256[] memory amountsOut);

    /* ────────────────────────────────────────────────────────────────────────────
                                      ROUTER FUNDS MGMT
    ─────────────────────────────────────────────────────────────────────────── */

    function transferRouterFunds(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address dest
    ) external;

    /* ────────────────────────────────────────────────────────────────────────────
                                         RECEIVE
    ─────────────────────────────────────────────────────────────────────────── */

    receive() external payable;
}
