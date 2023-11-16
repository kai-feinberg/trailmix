// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "../test/mock/MockV3Aggregator.sol";
import {MockISwapRouter} from "../test/mock/MockISwapRouter.sol";
import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../test/mock/MockERC20.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 10e8;

    struct NetworkConfig {
        address erc20Token;
        address stablecoin;
        address priceFeed;
        address router;
    }

    event HelperConfig__CreatedMockPriceFeed(address priceFeed);

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaLinkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaLinkConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            erc20Token: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            stablecoin: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
            priceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF, // LINK / USD
            router: 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008
        });
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        // Check to see if we set an active network config
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        //MockISwapRouter mockRouter = new MockISwapRouter();
        vm.stopBroadcast();
        emit HelperConfig__CreatedMockPriceFeed(address(mockPriceFeed));

        //DEPLOY REAL MOCK TO TEST WITH UNISWAP
        anvilNetworkConfig = NetworkConfig({
            erc20Token: address(new MockERC20("TestLINK", "LINK", 1000)),
            stablecoin: address(new MockERC20("TestUSDC", "USDC", 1000)),
            priceFeed: address(mockPriceFeed),
            router: address(0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008)
        });
    }
}
