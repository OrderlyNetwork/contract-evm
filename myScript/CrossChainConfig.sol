// SPDX-LICENSE-Identifier: MIT
pragma solidity ^0.8.17;

import "./Utils.sol";

contract CrossChainConfig {

    using StringCompare for string;

    mapping(uint256 => uint16) public _chainId2LzIdMapping;
    mapping(string => ChainConfig) public _chainConfigMapping;
    mapping(string => uint256) public _netork2ChainIdMapping;
    uint256[] public _chainIds;

    struct ChainConfig {
        string vaultNetwork;
        string ledgerNetwork;
        address ledgerCrossChainManager;
        address vaultCrossChainManager;
        address ledgerRelay;
        address vaultRelay;
        uint256 ledgerRelayTransfer;
        uint256 vaultRelayTransfer;
        uint256 ledgerChainId;
        uint16 ledgerLzChainId;
        uint256 vaultChainId;
        uint16 vaultLzChainId;
        bytes lzCrossChainPath;
    }

    constructor() {
        _chainId2LzIdMapping[986532] = 10174;
        _chainId2LzIdMapping[43113] = 10106;
        _chainId2LzIdMapping[80001] = 10109;
        _chainIds.push(986532);
        _chainIds.push(43113);
        _chainIds.push(80001);

        _netork2ChainIdMapping["orderly"] = 986532;
        _netork2ChainIdMapping["fuji"] = 43113;
        _netork2ChainIdMapping["mumbai"] = 80001;

        _chainConfigMapping["fuji-mumbai"] = getFujiMumbaiChainConfig();
    }

    function getChainConfig(string memory crosschainOption) public view returns (ChainConfig memory) {
        return _chainConfigMapping[crosschainOption];
    }

    function getChainIds() public view returns (uint256[] memory) {
        return _chainIds;
    }

    function getFujiMumbaiChainConfig() internal pure returns (ChainConfig memory) {
        address ledgerRelay = 0x160aeA20EdB575204849d91F7f3B7c150877a26A;
        address vaultRelay = 0xc8E38C1Fd1422f49DB592BAe619080EA5Deb50e0;
        return ChainConfig({
            vaultNetwork: "fuji",
            ledgerNetwork: "mumbai",
            ledgerCrossChainManager: 0x5771B915a19f1763274Ef97a475C4525dA7F963F,
            vaultCrossChainManager: 0x339c8523d4c2354E392424D76C2c3546Df2e7a13,
            ledgerRelay: ledgerRelay,
            vaultRelay: vaultRelay,
            // 2 native token (Mumbai)
            ledgerRelayTransfer: 2_000_000_000_000_000_000,
            // 1 native token (fuji)
            vaultRelayTransfer: 1_000_000_000_000_000_000,
            ledgerChainId: 986532,
            ledgerLzChainId: 10174,
            vaultChainId: 43113,
            vaultLzChainId: 10106,
            lzCrossChainPath: abi.encodePacked(ledgerRelay, vaultRelay)
        });
    }

}