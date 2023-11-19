// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
// import {MockISwapRouter} from "../test/mock/MockISwapRouter.sol";
// import {MockERC20} from "../test/mock/MockERC20.sol";

// contract DeployMockISwapRouter is Script {
//     MockERC20 public tokenIn;
//     MockERC20 public tokenOut;
//     MockISwapRouter public mockISwapRouter;

//     function run() external {
//         vm.startBroadcast();

//         // Deploy ERC20 mocks
//         tokenIn = new MockERC20("Token In", "TKI", 1e18); // 1 token = 1e18 decimals
//         tokenOut = new MockERC20("Token Out", "TKO", 1e18); // 1 token = 1e18 decimals

//         // Mint tokens to the deployer for testing
//         tokenIn.mint(address(this), 1000e18); // Mint 1000 Token In
//         tokenOut.mint(address(this), 1000e18); // Mint 1000 Token Out

//         // Deploy MockISwapRouter with an example exchange rate
//         uint256 exchangeRate = 1; // 1 Token In = 1 Token Out
//         mockISwapRouter = new MockISwapRouter(address(tokenIn), address(tokenOut), exchangeRate);

//         // Transfer Token Out to MockISwapRouter to simulate liquidity
//         tokenOut.transfer(address(mockISwapRouter), 500e18); // Transfer 500 Token Out to MockISwapRouter

//         vm.stopBroadcast();
//     }
// }
