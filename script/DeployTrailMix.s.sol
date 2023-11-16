// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TrailMix} from "../src/TrailMixV1.sol";

contract DeployTrailMix is Script {

    function run() external returns (TrailMix, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (address erc20Token, address stablecoin, address router, address priceFeed) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        TrailMix trailMix = new TrailMix(erc20Token, stablecoin, router, priceFeed);
        vm.stopBroadcast();
        return (trailMix, helperConfig);
    }
}