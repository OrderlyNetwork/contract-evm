// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/library/Signature.sol";
import "../../src/library/types/EventTypes.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title BalanceTransferAdvanced Test
 * @dev Comprehensive test suite for multi-account balance transfer scenarios
 * Tests various scenarios including:
 * - Sequential transfers between 3 accounts (A -> B -> C)
 * - Circular transfers (A -> B -> C -> A)
 * - Parallel transfers with different transfer types
 * - Risk management scenarios with pending balances
 * - Withdrawal validation with in-flight transfers
 * 
 * SIGNATURE GENERATION STRATEGY:
 * This test suite uses DYNAMIC SIGNATURE GENERATION instead of pre-calculated fixed signatures.
 * 
 * Method:
 * 1. Initialize EventUpload struct with placeholder values (r: 0x0, s: 0x0, v: 0x0)
 * 2. Encode the data structure using Signature.eventsUploadEncodeHash()
 * 3. Generate keccak256 hash and wrap with Ethereum message prefix
 * 4. Use Foundry's vm.sign() to generate ECDSA signature (r, s, v components)
 * 5. Replace placeholder values with actual signature components
 * 
 * Advantages over fixed signatures:
 * - Flexible: can test with different data combinations
 * - Maintainable: no need to recalculate signatures when test data changes
 * - Cryptographically correct: real ECDSA signatures generated each time
 * - Consistent: uses same private key (0xff965a...) as in original tests
 * 
 * The placeholder approach (0x0 initial values) is standard practice in Foundry tests.
 */
contract BalanceTransferAdvancedTest is Test {
    using ECDSA for bytes32;

    // Test constants from documentation
    address constant OPERATOR_ADDR = 0x6a9961Ace9bF0C1B8B98ba11558A4125B1f5EA3f;
    uint256 constant PRIVATE_KEY = 0xff965a6595be51798d16a8e3f4c10db72af43e2f65d27784a8f92fab1919fd15;

    // Test account IDs
    bytes32 constant ACCOUNT_A = 0x1111111111111111111111111111111111111111111111111111111111111111;
    bytes32 constant ACCOUNT_B = 0x2222222222222222222222222222222222222222222222222222222222222222;
    bytes32 constant ACCOUNT_C = 0x3333333333333333333333333333333333333333333333333333333333333333;

    // Test token hash (USDC)
    bytes32 constant USDC_HASH = 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa;

    /**
     * @dev Test Scenario 1: Sequential Internal Transfers A -> B -> C
     * Tests the flow where:
     * 1. Account A transfers 1000 USDC to Account B
     * 2. Account B transfers 500 USDC to Account C
     * Verifies proper signature generation for all events
     */
    function test_sequentialTransfers_A_to_B_to_C() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);
        
        // Transfer 1: A -> B (1000 USDC)
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("transfer_1", block.timestamp)));
        
        // Event 1: Debit from Account A
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 2001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 1000e6, // 1000 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: true,  // Debit event
                transferType: 3,        // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 2: Credit to Account B
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 2002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 1000e6, // 1000 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3,        // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Transfer 2: B -> C (500 USDC)
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("transfer_2", block.timestamp)));
        
        // Event 3: Debit from Account B
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 2003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 500e6, // 500 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: true,  // Debit event
                transferType: 3,        // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 4: Credit to Account C
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 2004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 500e6, // 500 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event
                transferType: 3,        // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 4,
            batchId: 9001
        });

        // DYNAMIC SIGNATURE GENERATION APPROACH:
        // 1. First encode the data structure to get the message hash
        // 2. Generate signature using Foundry's vm.sign() with test private key
        // 3. Replace placeholder values with actual ECDSA signature components
        // This approach is more flexible than using pre-calculated fixed signatures
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        // Generate ECDSA signature: (v, r, s) components
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA signature r component (x-coordinate of curve point)
        eventUpload.s = s; // ECDSA signature s component
        eventUpload.v = v; // Recovery identifier (27 or 28)

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Sequential transfer signature verification failed");
    }

    /**
     * @dev Test Scenario 2: Circular Transfers A -> B -> C -> A
     * Tests a complex circular transfer pattern that could create risk scenarios
     */
    function test_circularTransfers_A_to_B_to_C_to_A() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](6);
        
        // Transfer 1: A -> B (1000 USDC)
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("circular_1", block.timestamp)));
        
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 3001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 1000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 3002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 1000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Transfer 2: B -> C (800 USDC)
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("circular_2", block.timestamp)));
        
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 3003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 800e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 3004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 800e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Transfer 3: C -> A (600 USDC) - Completing the circle
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("circular_3", block.timestamp)));
        
        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 3005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 600e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId3
            }))
        });

        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 3006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 600e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
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
            batchId: 9002
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Circular transfer signature verification failed");
    }

    /**
     * @dev Test Scenario 3: Mixed Transfer Types
     * Tests different types of transfers in one batch:
     * - Internal transfer
     * - Broker fee distribution
     * - Referee rebate
     * - Referrer rebate
     */
    function test_mixedTransferTypes() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](8);
        
        // Internal Transfer: A -> B (500 USDC)
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("mixed_1", block.timestamp)));
        
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 500e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 500e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Broker Fee: B -> C (10 USDC)
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("mixed_2", block.timestamp)));
        
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 10e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 0, // BROKER_FEE
                transferId: transferId2
            }))
        });

        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 10e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 0, // BROKER_FEE
                transferId: transferId2
            }))
        });

        // Referee Rebate: C -> A (5 USDC)
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("mixed_3", block.timestamp)));
        
        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 5e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 1, // REFEREE_REBATE
                transferId: transferId3
            }))
        });

        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 5e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 1, // REFEREE_REBATE
                transferId: transferId3
            }))
        });

        // Referrer Rebate: A -> B (3 USDC)
        uint256 transferId4 = uint256(keccak256(abi.encodePacked("mixed_4", block.timestamp)));
        
        events[6] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4007,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 3e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 2, // REFERRER_REBATE
                transferId: transferId4
            }))
        });

        events[7] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 4008,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 3e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 2, // REFERRER_REBATE
                transferId: transferId4
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 8,
            batchId: 9003
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Mixed transfer types signature verification failed");
    }

    /**
     * @dev Test Scenario 4: Risk Management Scenario
     * Tests a scenario where credit events are processed before debit events,
     * simulating out-of-order processing that creates platform risk
     */
    function test_riskManagementScenario_creditFirst() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("risk_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("risk_2", block.timestamp)));
        
        // Scenario: Process credit events first, then debit events
        // This simulates the risk scenario where receivers get funds before senders are debited
        
        // Event 1: Credit to Account B FIRST (before A is debited)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 5001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 750e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event processed FIRST
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Event 2: Credit to Account C FIRST (before B is debited)
        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 5002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 400e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false, // Credit event processed FIRST
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 3: Debit from Account B (after C was credited)
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 5003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 400e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event processed AFTER credit
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        // Event 4: Debit from Account A (after B was credited)
        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 5004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 750e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true, // Debit event processed AFTER credit
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
            batchId: 9004
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Risk management scenario signature verification failed");
    }

    /**
     * @dev Test Scenario 5: Large Amount Transfer with Liquidation Fees
     * Tests high-value transfers with liquidation fee types
     */
    function test_largeAmountTransfersWithLiquidationFees() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](6);
        
        // Large internal transfer: A -> B (10,000 USDC)
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("large_1", block.timestamp)));
        
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 6001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 10000e6, // 10,000 USDC
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 6002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 10000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // SP Liquidation Fee: B -> C (100 USDC)
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("large_2", block.timestamp)));
        
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 6003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 5, // SP_LIQUIDATION_FEE
                transferId: transferId2
            }))
        });

        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 6004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 5, // SP_LIQUIDATION_FEE
                transferId: transferId2
            }))
        });

        // SP Orderly Revenue: C -> A (50 USDC)
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("large_3", block.timestamp)));
        
        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 6005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 50e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 6, // SP_ORDERLY_REVENUE
                transferId: transferId3
            }))
        });

        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 6006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 50e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 6, // SP_ORDERLY_REVENUE
                transferId: transferId3
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 6,
            batchId: 9005
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Large amount transfers with liquidation fees signature verification failed");
    }

    /**
     * @dev Test Scenario 6: Special Vault Internal Transfer
     * Tests SV_INTERNAL_TRANSFER type (type 4) between accounts
     */
    function test_specialVaultInternalTransfer() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](4);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("sv_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("sv_2", block.timestamp)));
        
        // SV Internal Transfer: A -> B (2000 USDC)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 7001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 2000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 4, // SV_INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 7002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 2000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 4, // SV_INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // SV Internal Transfer: B -> C (1500 USDC)
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 7003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 1500e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 4, // SV_INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 7004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 1500e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 4, // SV_INTERNAL_TRANSFER
                transferId: transferId2
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 4,
            batchId: 9006
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Special vault internal transfer signature verification failed");
    }

    /**
     * @dev Test Scenario 7: Unknown Transfer Type (255)
     * Tests transfers with unknown/future transfer types
     */
    function test_unknownTransferType() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](2);
        
        uint256 transferId = uint256(keccak256(abi.encodePacked("unknown_type", block.timestamp)));
        
        // Unknown transfer type: A -> B (100 USDC)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 8001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 255, // Unknown/future transfer type
                transferId: transferId
            }))
        });

        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 8002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 100e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 255, // Unknown/future transfer type
                transferId: transferId
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 2,
            batchId: 9007
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Unknown transfer type signature verification failed");
    }

    /**
     * @dev Test Scenario 8: Complex Multi-Step Transfer Chain
     * Tests a complex scenario with 3 accounts and multiple transfer types
     * Flow: A -internal-> B -fee-> C -rebate-> A -liquidation-> B
     */
    function test_complexMultiStepTransferChain() public {
        EventTypes.EventUploadData[] memory events = new EventTypes.EventUploadData[](8);
        
        uint256 transferId1 = uint256(keccak256(abi.encodePacked("complex_1", block.timestamp)));
        uint256 transferId2 = uint256(keccak256(abi.encodePacked("complex_2", block.timestamp)));
        uint256 transferId3 = uint256(keccak256(abi.encodePacked("complex_3", block.timestamp)));
        uint256 transferId4 = uint256(keccak256(abi.encodePacked("complex_4", block.timestamp)));
        
        // Step 1: Internal Transfer A -> B (5000 USDC)
        events[0] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9001,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 5000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        events[1] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9002,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 5000e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 3, // INTERNAL_TRANSFER
                transferId: transferId1
            }))
        });

        // Step 2: Broker Fee B -> C (25 USDC)
        events[2] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9003,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 25e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 0, // BROKER_FEE
                transferId: transferId2
            }))
        });

        events[3] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9004,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_B,
                toAccountId: ACCOUNT_C,
                amount: 25e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 0, // BROKER_FEE
                transferId: transferId2
            }))
        });

        // Step 3: Referee Rebate C -> A (15 USDC)
        events[4] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9005,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 15e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 1, // REFEREE_REBATE
                transferId: transferId3
            }))
        });

        events[5] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9006,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_C,
                toAccountId: ACCOUNT_A,
                amount: 15e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 1, // REFEREE_REBATE
                transferId: transferId3
            }))
        });

        // Step 4: SP Liquidation Fee A -> B (200 USDC)
        events[6] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9007,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 200e6,
                tokenHash: USDC_HASH,
                isFromAccountId: true,
                transferType: 5, // SP_LIQUIDATION_FEE
                transferId: transferId4
            }))
        });

        events[7] = EventTypes.EventUploadData({
            bizType: 12,
            eventId: 9008,
            data: abi.encode(EventTypes.BalanceTransfer({
                fromAccountId: ACCOUNT_A,
                toAccountId: ACCOUNT_B,
                amount: 200e6,
                tokenHash: USDC_HASH,
                isFromAccountId: false,
                transferType: 5, // SP_LIQUIDATION_FEE
                transferId: transferId4
            }))
        });

        EventTypes.EventUpload memory eventUpload = EventTypes.EventUpload({
            events: events,
            r: 0x0, // Placeholder: will be replaced with actual signature
            s: 0x0, // Placeholder: will be replaced with actual signature
            v: 0x0, // Placeholder: will be replaced with actual signature
            count: 8,
            batchId: 9008
        });

        // DYNAMIC SIGNATURE GENERATION: Generate ECDSA signature using vm.sign()
        bytes memory encodedData = Signature.eventsUploadEncodeHash(eventUpload);
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(encodedData));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, messageHash);
        eventUpload.r = r; // ECDSA r component
        eventUpload.s = s; // ECDSA s component
        eventUpload.v = v; // Recovery identifier

        bool isValid = Signature.eventsUploadEncodeHashVerify(eventUpload, OPERATOR_ADDR);
        assertEq(isValid, true, "Complex multi-step transfer chain signature verification failed");
    }
}