// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TrailMix} from "../src/TrailMixV2.sol";

contract DeployTrailMix is Script {
    address public constant USER = address(1);

    function run() external returns (TrailMix, HelperConfig) {
        uint256 trailPercent = 10;
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (address erc20Token, address stablecoin, address router, address priceFeed) = helperConfig.activeNetworkConfig();

        
        vm.startBroadcast();
        TrailMix trailMix = new TrailMix(USER, erc20Token, stablecoin, router, priceFeed, trailPercent);
        vm.stopBroadcast();
        return (trailMix, helperConfig);
    }
}