// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DeployTrailMix} from "../../script/DeployTrailMix.s.sol";
import {TrailMix} from "../../src/TrailMixV1.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";
import {MockISwapRouter} from "../mock/MockISwapRouter.sol";

contract FundMeTest is StdCheats, Test {
    TrailMix public trailMix;
    HelperConfig public helperConfig;

    address erc20Token;
    address stablecoin;
    address priceFeed;
    address router;

    /**
     * helper config is struct of this type:
    struct NetworkConfig {
        address erc20Token;
        address stablecoin;
        address priceFeed;
        address router;
    }
    **/
    uint256 public constant SEND_VALUE = 0.1 ether; // just a value to make sure we are sending enough!
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1;

    address public constant USER = address(1);

    function setUp() external {
        DeployTrailMix deployer = new DeployTrailMix();
        (trailMix, helperConfig) = deployer.run();
        vm.deal(USER, STARTING_USER_BALANCE);
        (erc20Token, stablecoin, priceFeed, router) = helperConfig.activeNetworkConfig();
    }

    function testPriceFeedSetCorrectly() public {
        address retreivedPriceFeed = address(trailMix.getPriceFeed());
        (,,address expectedPriceFeed,) = helperConfig.activeNetworkConfig();
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testConstructorInitialization() public{
        // Retrieve the expected values from HelperConfig
        (address expectedERC20Token, 
         address expectedStablecoin, 
         address expectedPriceFeed,
         address expectedUniswapRouter) = helperConfig.activeNetworkConfig();

        // Asserting that the contract's state variables match the expected values
        assertEq(trailMix.getERC20TokenAddress(), expectedERC20Token, "ERC20 token address mismatch");
        assertEq(trailMix.getStablecoinAddress(), expectedStablecoin, "Stablecoin address mismatch");
        assertEq(trailMix.getUniswapRouterAddress(), expectedUniswapRouter, "Uniswap router address mismatch");
        assertEq(trailMix.getPriceFeedAddress(), expectedPriceFeed, "Price feed address mismatch");
    }

    function testSuccessfulDeposit() public {
        // Arrange: Define deposit amount and tslThreshold
        uint256 depositAmount = 1 ether;
        uint256 tslThreshold = 10;  // Example threshold value

        // Arrange: Set up user's ERC20 balance and approve TrailMix contract to spend tokens
        MockERC20 erc20 = MockERC20(erc20Token);
        erc20.mint(USER, depositAmount);

        vm.startPrank(USER);
        erc20.approve(address(trailMix), depositAmount);

        // Act: Call the deposit function
        trailMix.deposit(depositAmount, tslThreshold);

        vm.stopPrank();
        // Assert: Check if the deposit was successful
        // (You will need corresponding view functions in TrailMix to retrieve TSL details and user data)
        uint256 userTSLId = trailMix.getUserData(USER).s_activeTSLId;
        TrailMix.TrailingStopLoss memory tsl = trailMix.getTSLDetails(userTSLId);
        assertEq(tsl.s_totalTokenAmount, depositAmount, "TSL total token amount mismatch");
        assertEq(tsl.s_priceThreshold, tslThreshold, "TSL price threshold mismatch");
    }

    // function testFundFailsWithoutEnoughETH() public {
    //     vm.expectRevert();
    //     fundMe.fund();
    // }

    // function testFundUpdatesFundedDataStructure() public {
    //     vm.startPrank(USER);
    //     fundMe.fund{value: SEND_VALUE}();
    //     vm.stopPrank();

    //     uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
    //     assertEq(amountFunded, SEND_VALUE);
    // }

    // function testAddsFunderToArrayOfFunders() public {
    //     vm.startPrank(USER);
    //     fundMe.fund{value: SEND_VALUE}();
    //     vm.stopPrank();

    //     address funder = fundMe.getFunder(0);
    //     assertEq(funder, USER);
    // }

    // https://twitter.com/PaulRBerg/status/1624763320539525121

    // modifier funded() {
    //     vm.prank(USER);
    //     fundMe.fund{value: SEND_VALUE}();
    //     assert(address(fundMe).balance > 0);
    //     _;
    // }

    // function testOnlyOwnerCanWithdraw() public funded {
    //     vm.expectRevert();
    //     fundMe.withdraw();
    // }

}
