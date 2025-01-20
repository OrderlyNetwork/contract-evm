// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "contract-evm/src/library/Ed25519/Ed25519.sol";
import "contract-evm/src/library/Bytes32ToAsciiBytes.sol";

// https://github.com/Near-One/rainbow-bridge/blob/master/contracts/eth/nearbridge/test/Ed25519.js
// https://github.com/Near-One/rainbow-bridge/blob/master/contracts/eth/nearbridge/test/ed25519-tests.json
contract Ed25519Test is Test {
    function test_ed25519_B1() public {
        bytes32 k = hex"5d196f3f0d495ffebe06d09dded803b3f275e131e3f662b3904e4929d07b1af8";
        bytes32 r = hex"0d5f61d895fbe3bc7d19b7877a1cbc8677061757f2c614f576799ba3b6092186";
        bytes32 s = hex"640ac5fb43090676cc359baf77f2a0c6bd42dc089660abcb7e64de1b44d67c00";
        bytes memory m = hex"0bc7432ef070a5d9e30fa55a9de5fa0ffd5d9ad11cc860e017195e5632a411aae10d617d3bb865940a";
        bool shouldSucc = true;
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertEq(isSucc, shouldSucc);
    }

    function test_ed25519_B2() public {
        bytes32 k = hex"c5b00ebf9d9a8aede9b4c9e191d0b33f3e1a9d8c8be5430d47434a37d590d8a1";
        bytes32 r = hex"160257b1a6fab31596fd2e8da09ac1cb1373ce1ef795b7cf31eafe065a6abbe5";
        bytes32 s = hex"3e51955de5b11724c4653bcdfe57ff8bc257468090e42b17f55bcbb1347d5f0e";
        bytes memory m = hex"fd2e310677abca51ff02a35a00dd56a0b65e1cf5308f8e7ed0edc0defc147aae10652f420b0436f4aa";
        bool shouldSucc = false;
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertEq(isSucc, shouldSucc);
    }

    function test_ed25519_B3() public {
        bytes32 k = hex"396ea9a022e06f96d54e752adbae3fff66734b33f2975a889f98a1a96f2217cd";
        bytes32 r = hex"43e378092935b978f835f72585190327941021c4005ab4ec0d0da9b2faf1cc4f";
        bytes32 s = hex"86ff70ed416d3ce89e0490925ca0e8218b20934b23970ae369b75a0de3ab9706";
        bytes memory m = hex"bec5e68b944de337dfd3ec593313e571f47680f2609dae3089bd7aee47c779284396e271250e3aa74b";
        bool shouldSucc = false;
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertEq(isSucc, shouldSucc);
    }

    // generate by myself
    function test_ed25519_B4() public {
        string memory rawStr = "The quick brown fox jumps over the lazy dog";
        bytes32 m1 = keccak256(abi.encodePacked(rawStr));
        // bytes32 m1 = hex"4d741b6f1eb29cb2a9b9911c82f56fa8d73b04959d3d9d222895df6c0b28aa15";
        bytes32 k = hex"0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87";
        bytes32 r = hex"ab129805e950d5f5d8f2b0b940a974b6d9df4f9be94d9a30dfe9fdc4591283f7";
        bytes32 s = hex"16eb263d9b351b4ac10fe0cce4c567b98a2eecfff4aee57afc4010591e401708";
        bytes9 m2 = hex"000000000000000000";
        bytes memory m = abi.encodePacked(m1, m2);
        bool shouldSucc = true;
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertEq(isSucc, shouldSucc);
    }

    // generate by myself
    function test_ed25519_B5() public {
        bytes32 k = hex"0fb9ba52b1f09445f1e3a7508d59f0797923acf744fbe2da303fb06da859ee87";
        bytes32 r = hex"931e6384feaa0a1e544458bc57fd785a25eb3a1331b5df67f816d096f9445d53";
        bytes32 s = hex"022dde995209adcd13bf5ad035844824e997b717f5ff27aa2aadfd0733da7107";
        bytes32 v = hex"4d741b6f1eb29cb2a9b9911c82f56fa8d73b04959d3d9d222895df6c0b28aa15";
        bytes memory m = Bytes32ToAsciiBytes.bytes32ToAsciiBytes(v);
        // bytes memory m =
        //     hex"34643734316236663165623239636232613962393931316338326635366661386437336230343935396433643964323232383935646636633062323861613135";
        bool shouldSucc = true;
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertEq(isSucc, shouldSucc);
    }

    // generate by solana tx signature
    function test_ed25519_C1() public {
        bytes32 k = hex"8d74357c58760282acca9f5af78bb51e2adaa44d6248bb9243116e9ad4a5b4a9";
        bytes32 r = hex"2c69d796b4eed8e46a5406433c8c578c7a788a1452ae545b5223a23338cefb4d";
        bytes32 s = hex"6577096cf4d3f60cb7810662879c55834b1d523a9dbb59dba979dccc51c6ba0b";
        bytes memory m =
            hex"010002038d74357c58760282acca9f5af78bb51e2adaa44d6248bb9243116e9ad4a5b4a90306466fe5211732ffecadba72c39be7bc8ce5bbc5f7126b2c439b3a40000000054a535a992921064d24e87160da387c7c35b5ddbc92bb81e41fa8404105448d000000000000000000000000000000000000000000000000000000000000000003010009030000000000000000010005020000000002004034643734316236663165623239636232613962393931316338326635366661386437336230343935396433643964323232383935646636633062323861613135";
        bool shouldSucc = true;
        bool isSucc = Ed25519.verify(k, r, s, m);
        assertEq(isSucc, shouldSucc);
    }
}
