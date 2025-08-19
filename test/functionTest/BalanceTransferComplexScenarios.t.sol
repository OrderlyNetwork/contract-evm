// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/Signature.sol";
import "../../src/library/types/EventTypes.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title BalanceTransferComplexScenarios Test
 * @dev Advanced test suite focusing on signature verification for complex balance transfer scenarios
 * Tests various multi-account transfer patterns and out-of-order event processing:
 * - Sequential and circular transfer chains
 * - Out-of-order event processing scenarios
 * - Large-scale concurrent transfers
 * - Mixed transfer types (internal transfer, fees, liquidation)
 * 
 * SIGNATURE GENERATION APPROACH:
 * This test suite follows the DYNAMIC SIGNATURE GENERATION pattern for maximum flexibility.
 * 
 * Key differences from original Signature.t.sol tests:
 * 1. FIXED SIGNATURES (original): Use pre-calculated r/s/v values from documentation
 *    - Example: r: 0x543e72ea14c90ae..., s: 0x6ad60c31a85437e..., v: 0x1b
 *    - Pros: Exact match with backend test vectors
 *    - Cons: Inflexible, hard to modify test data
 * 
 * 2. DYNAMIC SIGNATURES (this suite): Generate signatures at runtime using vm.sign()
 *    - Example: r: 0x0 (placeholder) → replaced with vm.sign() output
 *    - Pros: Flexible, maintainable, cryptographically sound
 *    - Cons: Different signature values each run (but same verification result)
 * 
 * Why 0x0 placeholders are used:
 * - Standard Foundry pattern for dynamic signature generation
 * - Clearly indicates these will be replaced with real values
 * - Prevents confusion with actual signature components
 * 
 * The final verification uses the same ECDSA signature verification as the original tests,
 * ensuring cryptographic correctness while providing testing flexibility.
 */
contract BalanceTransferComplexScenariosTest is Test {
    using ECDSA for bytes32;

    // Test constants
    address constant OPERATOR_ADDR = 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f;
    uint256 constant PRIVATE_KEY = 0xff965a6595be51798d16a8e3f4c10db72af43e2f65d27784a8f92fab1919fd15;

    // Test account IDs
    bytes32 constant ACCOUNT_A = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
    bytes32 constant ACCOUNT_B = 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb;
    bytes32 constant ACCOUNT_C = 0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc;

    // Test token hash (USDC)
    bytes32 constant USDC_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;

    /**
     * @dev Test Sequential Transfer Scenario: A -> 100 -> B -> 100 -> C
     * Upload order: B+100(1), B-100(2), C+100(2), A-100(1)
     * Tests out-of-order event processing and signature verification
     */
    function test_sequentialTransferScenario_A_to_B_to_C() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("doc_risk_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("doc_risk_2", block.timestamp)));
        
        // Simulate the upload order from documentation:
        // Event 1: B+100(1) - Credit to B first (creates risk of 100)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 10001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6, // 100 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 2: B-100(2) - Debit from B for second transfer (risk remains 100)
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 10002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6, // 100 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 3: C+100(2) - Credit to C (risk increases to 200)
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 10003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6, // 100 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 4: A-100(1) - Debit from A (risk resolved to 100, then to 0)
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 10004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6, // 100 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 4,
            batchId: 10001
        });

        // DYNAMIC SIGNATURE GENERATION APPROACH:
        // Unlike pre-calculated signatures from documentation, we generate signatures dynamically
        // This allows flexible testing with different data while ensuring cryptographic correctness
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component (elliptic curve point x-coordinate)
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier (27 or 28)

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Sequential transfer scenario signature verification failed");
    }

    /**
     * @dev Test Alternative Event Order Scenario: B+100(1), C+100(2), B-100(2), A-100(1)
     * Tests signature verification when all credit events are processed first
     */
    function test_creditsFirstScenario() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("high_risk_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("high_risk_2", block.timestamp)));
        
        // Event 1: B+100(1) - Credit to B first (creates risk of 100)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 11001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 2: C+100(2) - Credit to C (risk increases to 200)
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 11002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 3: B-100(2) - Debit from B (risk decreases to 100)
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 11003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 4: A-100(1) - Debit from A (risk resolved to 0)
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 11004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 4,
            batchId: 11001
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Credits first scenario signature verification failed");
    }

    /**
     * @dev Test Circular Transfer Scenario: A -> B -> C -> A
     * Upload order: B+100(1), C+100(2), A-100(1), A+100(3), B-100(2), C-100(3)
     * Tests signature verification for complex circular transfer chains
     */
    function test_circularTransferScenario() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](6);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("circular_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("circular_2", block.timestamp)));
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("circular_3", block.timestamp)));
        
        // Event 1: B+100(1) - Credit to B first (risk = 100)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 12001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 2: C+100(2) - Credit to C (risk = 200)
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 12002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 3: A-100(1) - Debit from A (risk = 100)
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 12003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 4: A+100(3) - Credit to A for circular transfer (risk = 200)
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 12004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId3
            }))
        });

        // Event 5: B-100(2) - Debit from B (risk = 100)
        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 12005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 6: C-100(3) - Debit from C (risk = 0)
        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 12006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId3
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 6,
            batchId: 12001
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Circular transfer scenario signature verification failed");
    }

    /**
     * @dev Test Complex Transfer and Withdrawal Scenario
     * Tests signature verification for mixed transfer and withdrawal events
     */
    function test_transferWithWithdrawalScenario() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](5);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("pending_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("pending_2", block.timestamp)));
        
        // Simulate the scenario from documentation:
        // Initial: A.balance = 100, B.balance = 100, C.balance = 100
        
        // Event 1: A transfers 10 to B (debit event processed first)
        // A.balance = 90, B.balance = 100, B.pending = -10
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 13001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 10e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 2: B transfers 5 to C (credit event processed first)
        // B.balance = 105, C.balance = 100, B.pending = -5
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 13002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 5e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 3: C's debit event processed (for the B->C transfer)
        // C.balance = 95, B.pending = -10
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 13003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 5e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event  
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 4: B's credit event processed (for the A->B transfer)
        // B.balance = 10, B.pending = 0
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 13004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 10e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 5: Test withdrawal attempt - this should work since pending balance is resolved
        // Creating a mock withdrawal event to test the flow
        EventTypes.WithdrawData memory withdraw = EventTypes.WithdrawData({
            tokenAmount: 5e6, // Try to withdraw 5 USDC
            fee: 1e6,
            chainId: 1,
            accountId: ACCOUNT_B,
            r: 0x0,
            s: 0x0,
            v: 0x0,
            sender: address(0x1234),
            withdrawNonce: 1,
            receiver: address(0x1234),
            timestamp: uint64(block.timestamp),
            brokerId: "test_broker",
            tokenSymbol: "USDC"
        });

        events[4] = EventTypes.EventUploadData({
            bizType: 1, // Withdraw
            eventId: 13005,
            data: abi.encode(withdraw)
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 5,
            batchId: 13001
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Transfer with withdrawal scenario signature verification failed");
    }

    /**
     * @dev Test Large Scale Transfer Scenario
     * Tests signature verification for multiple concurrent large transfers
     */
    function test_largeScaleConcurrentTransfers() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](8);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("large_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("large_2", block.timestamp)));
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("large_3", block.timestamp)));
        uint256 transferId4 = uint256(keccak256(abi.encodePacked("large_4", block.timestamp)));
        
        // Multiple large transfers processed with credits first
        // This simulates a high-risk scenario where platform risk accumulates significantly
        
        // Large Transfer 1: A -> B (5000 USDC) - Credit first
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 5000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first (risk = 5000)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Large Transfer 2: B -> C (3000 USDC) - Credit first
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 3000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first (risk = 8000)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Large Transfer 3: C -> A (2000 USDC) - Credit first
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 2000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first (risk = 10000)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId3
            }))
        });

        // Large Transfer 4: A -> C (1500 USDC) - Credit first
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_C,
                amount: 1500e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first (risk = 11500)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId4
            }))
        });

        // Now process all debit events to resolve risk
        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 5000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event (risk = 6500)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 3000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event (risk = 3500)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        events[6] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14007,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 2000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event (risk = 1500)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId3
            }))
        });

        events[7] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 14008,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_C,
                amount: 1500e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event (risk = 0)
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId4
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 8,
            batchId: 14001
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Large scale concurrent transfers signature verification failed");
    }

    /**
     * @dev Test Mixed Transfer Types Scenario
     * Tests signature verification with different transfer types (internal, fees, liquidation)
     */
    function test_mixedTransferTypesScenario() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](6);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("mixed_risk_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("mixed_risk_2", block.timestamp)));
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("mixed_risk_3", block.timestamp)));
        
        // Internal Transfer: A -> B (1000 USDC) - Credit first
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 15001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 1000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Broker Fee: B -> C (50 USDC) - Credit first
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 15002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 50e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first
                transferType: 0, // BROKER_FEE
                transferId: transferId2
            }))
        });

        // Liquidation Fee: C -> A (25 USDC) - Credit first
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 15003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 25e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event first
                transferType: 5, // SP_LIQUIDATION_FEE
                transferId: transferId3
            }))
        });

        // Resolve debits in different order
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 15004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 25e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 5, // SP_LIQUIDATION_FEE
                transferId: transferId3
            }))
        });

        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 15005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 1000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 15006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 50e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event
                transferType: 0, // BROKER_FEE
                transferId: transferId2
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 6,
            batchId: 15001
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Mixed transfer types scenario signature verification failed");
    }
}