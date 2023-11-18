// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DeployTrailMix} from "../../script/DeployTrailMix.s.sol";
import {TrailMix} from "../../src/TrailMixV2.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {stdError} from "forge-std/StdError.sol";
import {MockERC20} from "../mock/MockERC20.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";
import {MockISwapRouter} from "../mock/MockISwapRouter.sol";

contract TrailMixTest is StdCheats, Test {
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

    address public TRAILMIX_ADDRESS;

    function setUp() external {
        DeployTrailMix deployer = new DeployTrailMix();
        (trailMix, helperConfig) = deployer.run();
        vm.deal(USER, STARTING_USER_BALANCE);
        (erc20Token, stablecoin, priceFeed, router) = helperConfig
            .activeNetworkConfig();
        TRAILMIX_ADDRESS = address(trailMix);
    }

    function testPriceFeedSetCorrectly() public {
        address retreivedPriceFeed = address(trailMix.getPriceFeedAddress());
        (, , address expectedPriceFeed, ) = helperConfig.activeNetworkConfig();
        assertEq(retreivedPriceFeed, expectedPriceFeed);
    }

    function testConstructorInitialization() public {
        // Retrieve the expected values from HelperConfig
        (
            address expectedERC20Token,
            address expectedStablecoin,
            address expectedPriceFeed,
            address expectedUniswapRouter
        ) = helperConfig.activeNetworkConfig();

        // Asserting that the contract's state variables match the expected values
        assertEq(
            trailMix.getERC20TokenAddress(),
            expectedERC20Token,
            "ERC20 token address mismatch"
        );
        assertEq(
            trailMix.getStablecoinAddress(),
            expectedStablecoin,
            "Stablecoin address mismatch"
        );
        assertEq(
            trailMix.getUniswapRouterAddress(),
            expectedUniswapRouter,
            "Uniswap router address mismatch"
        );
        assertEq(
            trailMix.getPriceFeedAddress(),
            expectedPriceFeed,
            "Price feed address mismatch"
        );
        assertEq(trailMix.getTrailAmount(), 10, "Trail amount mismatch");
        assertEq(trailMix.isTSLActive(), false, "TSL active mismatch");
    }

    function testOwnerInitialization() public {
        console.log("USER: ", USER);
        assertEq(trailMix.getOwner(), USER, "Owner not initialized correctly");
    }

    function testSuccessfulDeposit() public {
        uint256 depositAmount = 1 ether;
        uint256 tslThreshold = 100; // Example threshold

        // Arrange: Set up user's ERC20 balance and approve contract to spend tokens
        vm.prank(USER);
        MockERC20(erc20Token).mint(USER, depositAmount);
        vm.prank(USER);
        MockERC20(erc20Token).approve(TRAILMIX_ADDRESS, depositAmount);

        // Act: Call the deposit function
        assertEq(trailMix.isTSLActive(), false, "TSL active mismatch");
        vm.prank(USER);
        trailMix.deposit(depositAmount, tslThreshold);
        assertEq(trailMix.isTSLActive(), true, "TSL active mismatch");

        // Assert: Validate state changes and event emission
        assertEq(
            trailMix.getERC20Balance(),
            depositAmount,
            "ERC20 balance did not update correctly"
        );
        assertEq(
            trailMix.getTSLThreshold(),
            (tslThreshold * 90) / 100,
            "TSL threshold did not update correctly"
        );
    }

    function testAccess() public {
        vm.prank(address(2));
        vm.expectRevert();

        trailMix.deposit(1 ether, 100); //try to deposit from address(2) who is not the owner
    }

    function testDepositWithInvalidAmount() public {
        uint256 invalidDepositAmount = 0; // Invalid amount (0)
        uint256 tslThreshold = 100; // Example threshold

        // Expect revert for invalid deposit amount
        vm.expectRevert();
        vm.prank(USER);
        trailMix.deposit(invalidDepositAmount, tslThreshold);
    }

    function testDepositWithTransferFailure() public {
        uint256 depositAmount = 1e18; // 1 Mock Token
        uint256 tslThreshold = 100; // Example threshold

        // Set up to fail the ERC20 transfer
        //doesn't approve the contract to spend tokens so should rever the transfer
        vm.expectRevert();
        vm.prank(USER);
        trailMix.deposit(depositAmount, tslThreshold);
    }

    modifier activeTSL {
        uint256 depositAmount = 1 ether;
        uint256 tslThreshold = 100*10**18; // Example threshold
        // Arrange: Set up user's ERC20 balance and approve contract to spend tokens
        vm.prank(USER);
        MockERC20(erc20Token).mint(USER, depositAmount);
        vm.prank(USER);
        MockERC20(erc20Token).approve(TRAILMIX_ADDRESS, depositAmount);

        // Act: Call the deposit function
        vm.prank(USER);
        trailMix.deposit(depositAmount, tslThreshold);
        _;
    }

    function testGetLatestPrice() public activeTSL{
        // Arrange: Set expected price in mock aggregator
        int256 EXPECTED_PRICE = 100;
        MockV3Aggregator(priceFeed).updateAnswer(EXPECTED_PRICE);

        // Act: Call the getLatestPrice function
        uint256 latestPrice = trailMix.getLatestPrice();

        // Assert: Compare with expected price
        assertEq(
            int256(
                latestPrice /
                    10 ** (18 - MockV3Aggregator(priceFeed).decimals())
            ),
            EXPECTED_PRICE,
            "Latest price does not match expected price"
        );
    }

    function testUpdateTSLThresholdIndirectly() public activeTSL{
        // Arrange: Set initial conditions including current TSL threshold and ERC20 balance
        uint256 initialTSLThreshold = 100;
        uint256 depositAmount = 1 ether;

        vm.startPrank(USER);
        MockERC20(erc20Token).mint(USER, depositAmount);
        MockERC20(erc20Token).approve(TRAILMIX_ADDRESS, depositAmount);
        trailMix.deposit(depositAmount, initialTSLThreshold);
        vm.stopPrank();

        int256 EXPECTED_PRICE = 150; // Non-scaled price
        uint8 decimals = MockV3Aggregator(priceFeed).decimals();
        MockV3Aggregator(priceFeed).updateAnswer(EXPECTED_PRICE * int256(10**decimals));


        // Act: Call performUpkeep with data to trigger threshold update
        (, bytes memory performData) = trailMix.checkUpkeep(
            ""
        ); // Example data
        trailMix.performUpkeep(performData);


        // Assert: Verify that the TSL threshold is updated as expected
        uint256 newThreshold = trailMix.getTSLThreshold();

        //uses our getLatestPrice function to fetch latest price from oracle and standardize decimals
        uint256 expectedNewThreshold = (trailMix.getLatestPrice() * (100 - trailMix.getTrailAmount())) / 100; 
        assertEq(
            newThreshold,
            expectedNewThreshold,
            "TSL threshold was not updated correctly"
        );
    
    }
    
    function testCheckUpkeepNoUpkeepNeeded() public activeTSL {
        // Arrange: Set the price within the threshold range but not triggering an update
        uint256 tholdPrice = trailMix.getTSLThreshold();
        MockV3Aggregator mockPriceFeed = MockV3Aggregator(trailMix.getPriceFeedAddress());

        console.log(tholdPrice);
        mockPriceFeed.updateAnswer(int256(tholdPrice*105/(100*10 ** (18 - MockV3Aggregator(priceFeed).decimals())))); //price is 5% above threshold

        // Act: Call checkUpkeep
        (bool upkeepNeeded, bytes memory performData) = trailMix.checkUpkeep("");
        (bool triggerSell, bool updateThreshold, uint256 newThreshold) = abi.decode(performData, (bool, bool, uint256));
        console.log(newThreshold );
        console.log(triggerSell);
        console.log(updateThreshold);
        // Assert: No upkeep needed
        assertFalse(upkeepNeeded, "Upkeep should not be needed");
    }

    function testCheckUpkeepForSelling() public activeTSL{
        // Arrange: Set the price below the TSL threshold
        uint256 currentPrice = trailMix.getTSLThreshold();
        MockV3Aggregator mockPriceFeed = MockV3Aggregator(trailMix.getPriceFeedAddress());
        mockPriceFeed.updateAnswer(int256(currentPrice*99/(100*10**(18 - MockV3Aggregator(priceFeed).decimals()))));

        // Act: Call checkUpkeep
        (bool upkeepNeeded, bytes memory performData) = trailMix.checkUpkeep("");

        // Assert: Upkeep needed for selling
        assertTrue(upkeepNeeded, "Upkeep should be needed for selling");
        (bool triggerSell, bool updateThreshold,) = abi.decode(performData, (bool, bool, uint256));
        assertTrue(triggerSell, "Trigger sell should be true");
        assertFalse(updateThreshold, "Update threshold should be false");
    }

    function testCheckUpkeepForThresholdUpdate() public activeTSL{ 
        // Arrange: Set the price above the TSL threshold by the trail amount
        uint256 currentPrice = (trailMix.getTSLThreshold() * (101+trailMix.getTrailAmount())/ 100); //sets price 1% above the required amount to update the threshold.
        console.log(currentPrice);
        int256 currentPriceInt = int256(currentPrice);
        MockV3Aggregator mockPriceFeed = MockV3Aggregator(trailMix.getPriceFeedAddress());
        mockPriceFeed.updateAnswer(currentPriceInt);

        // Act: Call checkUpkeep
        (bool upkeepNeeded, bytes memory performData) = trailMix.checkUpkeep("");

        // Assert: Upkeep needed for threshold update
        assertTrue(upkeepNeeded, "Upkeep should be needed for threshold update");
        (bool triggerSell, bool updateThreshold,uint256 newThreshold) = abi.decode(performData, (bool, bool, uint256));
        assertFalse(triggerSell, "Trigger sell should be false");
        assertTrue(updateThreshold, "Update threshold should be true");
        assertEq(newThreshold, (trailMix.getLatestPrice() * (100 - trailMix.getTrailAmount()) / 100), "New threshold not correct");
    }

    function testCheckUpkeepWithNoActiveTSL() public{
        // Arrange: Ensure no active TSL
        // You may need to manipulate the contract state to reflect no active TSL

        // Act: Call checkUpkeep
        (bool upkeepNeeded, ) = trailMix.checkUpkeep("");

        // Assert: No upkeep needed
        assertFalse(upkeepNeeded, "Upkeep should not be needed when no TSL is active");
    }

}
