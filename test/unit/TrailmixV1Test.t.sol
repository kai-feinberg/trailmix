// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {DeployTrailMix} from "../../script/DeployTrailMix.s.sol";
import {TrailMix} from "../../src/TrailMixV1.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract FundMeTest is StdCheats, Test {
    TrailMix public trailMix;
    HelperConfig public helperConfig;

    uint256 public constant SEND_VALUE = 0.1 ether; // just a value to make sure we are sending enough!
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1;

    address public constant USER = address(1);

    // uint256 public constant SEND_VALUE = 1e18;
    // uint256 public constant SEND_VALUE = 1_000_000_000_000_000_000;
    // uint256 public constant SEND_VALUE = 1000000000000000000;

    function setUp() external {
        DeployTrailMix deployer = new DeployTrailMix();
        (trailMix, helperConfig) = deployer.run();
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testPriceFeedSetCorrectly() public {
        address retreivedPriceFeed = address(trailMix.getPriceFeed());
        // (address expectedPriceFeed) = helperConfig.activeNetworkConfig();
        (,,address expectedPriceFeed,) = helperConfig.activeNetworkConfig();
        assertEq(retreivedPriceFeed, expectedPriceFeed);
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
