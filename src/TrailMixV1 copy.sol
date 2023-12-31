// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma abicoder v2;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error InvalidAmount(); // Error for when the deposit amount is not positive
error TransferFailed(); // Error for when the token transfer fails
error TslDoesNotExist(); // Error for when the TSL does not exist

contract TrailMix is AutomationCompatibleInterface {
    // Struct for user data

    struct UserData {
        uint256 s_erc20Balance;
        uint256 s_stablecoinBalance;
        uint256 s_activeTSLId;
        uint256 s_tslTokenAmount;
    }

    // Struct for TSL data
    struct TrailingStopLoss {
        uint256 s_priceThreshold;
        uint256 s_totalTokenAmount;
        address[] s_participants; // Array of participant addresses
    }

    // Mappings for users and TSLs
    mapping(address => UserData) private s_users;
    mapping(uint256 => TrailingStopLoss) private s_trailingStopLosses;

    // Array for active TSL IDs
    uint256[] private s_activeTSLIds;

    // Global variables for ERC20 token, stablecoin, Uniswap Router, and Chainlink price feed
    address private s_erc20Token;
    address private s_stablecoin;
    ISwapRouter private s_uniswapRouter;
    AggregatorV3Interface private s_priceFeed;

    // Private counter for TSL IDs
    uint256 private s_nextTSLId = 1;

    event Deposit(address indexed user, uint256 amount, uint256 tslId);
    event TSLCreated(uint256 indexed tslId, uint256 threshold);
    event TSLUpdated(uint256 indexed tslId, uint256 newTotalAmount);

    // Constructor
    constructor(
        address _erc20Token,
        address _stablecoin,
        address _priceFeed,
        address _uniswapRouter

    ) {
        s_erc20Token = _erc20Token;
        s_stablecoin = _stablecoin;
        s_priceFeed = AggregatorV3Interface(_priceFeed);
        s_uniswapRouter = ISwapRouter(_uniswapRouter);

    }

    /**
     * @notice Deposit ERC20 tokens and create or update a Trailing Stop Loss (TSL)
     * @dev The function uses a bounded loop to check for existing TSLs within a tolerance range.
     *      The loop is bounded by the maximum number of distinct TSL thresholds possible,
     *      given the trail percentage and tolerance. This ensures gas efficiency and prevents
     *      unbounded loop execution. If the tolerance is .5% and there is a 10% trail then
     *      there can only ever be 20 unique stop losses active (as all others would be combined)
     * @param amount The amount of ERC20 tokens to deposit
     * @param tslThreshold The desired threshold for the TSL
     **/
    function deposit(uint256 amount, uint256 tslThreshold) external {
        if (amount <= 0) {
            revert InvalidAmount();
        }

        bool transferSuccess = IERC20(s_erc20Token).transferFrom(msg.sender, address(this), amount);
        if (!transferSuccess) {
            revert TransferFailed();
        }

        UserData storage user = s_users[msg.sender];
        user.s_erc20Balance += amount;

        // Check if user has an active TSL then add funds to it
        if (user.s_activeTSLId != 0) {
            // Add funds to existing TSL
            uint256 tslId = user.s_activeTSLId;
            TrailingStopLoss storage tsl = s_trailingStopLosses[tslId];
            tsl.s_totalTokenAmount += amount;
            user.s_tslTokenAmount += amount; // Update user's TSL token amount
            emit TSLUpdated(tslId, tsl.s_totalTokenAmount);
        } else {
            // Create new TSL
            createNewTSL(amount, tslThreshold, msg.sender);
        }

        emit Deposit(msg.sender, amount, user.s_activeTSLId);
    }

    function createNewTSL(uint256 amount, uint256 tslThreshold, address userAddress) private {
        uint256 tslId = s_nextTSLId++;
        TrailingStopLoss storage newTSL = s_trailingStopLosses[tslId];
        newTSL.s_priceThreshold = tslThreshold;
        newTSL.s_totalTokenAmount = amount;
        newTSL.s_participants.push(userAddress);
        s_activeTSLIds.push(tslId);

        s_users[userAddress].s_activeTSLId = tslId;
        s_users[userAddress].s_tslTokenAmount = amount;

        emit TSLCreated(tslId, tslThreshold);
    }

    function updatePriceThreshold(uint256 tslId, uint256 newThreshold) private {
        if(s_trailingStopLosses[tslId].s_priceThreshold == 0){
            revert TslDoesNotExist();
        }
        s_trailingStopLosses[tslId].s_priceThreshold = newThreshold;
        emit TSLUpdated(tslId, newThreshold);
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external override returns (bool upkeepNeeded, bytes memory performData) {}

    function performUpkeep(bytes calldata performData) external override {}


    //VIEW ONLY FUNCTIONS
    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    // View function to get user data
    function getUserData(address userAddress) public view returns (UserData memory) {
        return s_users[userAddress];
    }

    // View function to get TSL details
    function getTSLDetails(uint256 tslId) public view returns (TrailingStopLoss memory) {
        return s_trailingStopLosses[tslId];
    }

    // View function to get all active TSL IDs
    function getActiveTSLIds() public view returns (uint256[] memory) {
        return s_activeTSLIds;
    }

    // View function to get ERC20 token address
    function getERC20TokenAddress() public view returns (address) {
        return s_erc20Token;
    }

    // View function to get stablecoin address
    function getStablecoinAddress() public view returns (address) {
        return s_stablecoin;
    }

    // View function to get Uniswap router address
    function getUniswapRouterAddress() public view returns (address) {
        return address(s_uniswapRouter);
    }

    // View function to get Chainlink price feed address
    function getPriceFeedAddress() public view returns (address) {
        return address(s_priceFeed);
    }
}
