// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma abicoder v2;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error InvalidAmount(); // Error for when the deposit amount is not positive
error TransferFailed(); // Error for when the token transfer fails

contract TrailMix is AutomationCompatibleInterface, ReentrancyGuard {
    address private immutable i_owner;

    address private s_erc20Token;
    address private s_stablecoin;
    ISwapRouter private s_uniswapRouter;
    AggregatorV3Interface private s_priceFeed;
    uint256 private immutable s_trailAmount; // Amount to trail by

    uint256 private s_tslThreshold; // User's TSL threshold
    uint256 private s_erc20Balance;
    uint256 private s_stablecoinBalance; // User's ERC20 token balance
    bool private s_isTSLActive; // Indicates if the TSL is currently active

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event TSLUpdated(uint256 newThreshold);
    event SwapExecuted(uint256 amountIn, uint256 amountOut);

    constructor(
        address _owner,
        address _erc20Token,
        address _stablecoin,
        address _priceFeed,
        address _uniswapRouter,
        uint256 _trailAmount
    ) {
        i_owner = _owner;
        s_erc20Token = _erc20Token;
        s_stablecoin = _stablecoin;
        s_priceFeed = AggregatorV3Interface(_priceFeed);
        s_uniswapRouter = ISwapRouter(_uniswapRouter);
        s_isTSLActive = false;
        s_trailAmount = _trailAmount;
    }

    modifier onlyOwner() {
        require(msg.sender == i_owner, "Not the owner");
        _;
    }

    function deposit(uint256 amount, uint256 tslThreshold) external onlyOwner {
        if (amount <= 0) {
            revert InvalidAmount();
        }

        bool transferSuccess = IERC20(s_erc20Token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!transferSuccess) {
            revert TransferFailed();
        }

        s_erc20Balance += amount;

        if (!s_isTSLActive) {
            // If TSL is not active, set the threshold and activate TSL
            s_tslThreshold = (tslThreshold * (100 - s_trailAmount)) / 100;
            s_isTSLActive = true;
            emit TSLUpdated(tslThreshold);
        }
        emit Deposit(msg.sender, amount);
    }

    function withdraw() external onlyOwner {
        uint256 withdrawalAmount;

        if (!s_isTSLActive) {
            // If TSL is not active, assume user wants to withdraw stablecoins
            // Logic to handle stablecoin withdrawal
            withdrawalAmount = s_stablecoinBalance;
            if (withdrawalAmount <= 0) {
                revert InvalidAmount();
            }
            s_stablecoinBalance = 0;
            TransferHelper.safeTransfer(
                s_stablecoin,
                i_owner,
                withdrawalAmount
            );
        } else {
            // If TSL is active, user withdraws their ERC20 tokens
            withdrawalAmount = s_erc20Balance;
            if (withdrawalAmount <= 0) {
                revert InvalidAmount();
            }
            s_erc20Balance = 0;
            TransferHelper.safeTransfer(
                s_erc20Token,
                i_owner,
                withdrawalAmount
            );
            s_isTSLActive = false; // Deactivate TSL when withdrawal is made
        }

        emit Withdraw(i_owner, withdrawalAmount);
    }

    function updateTSLThreshold(uint256 newThreshold) private {
        s_tslThreshold = newThreshold;
        emit TSLUpdated(newThreshold);
    }

    function getLatestPrice() public view returns (uint256) {
        (
            ,
            /* uint80 roundID */ int256 price /* uint startedAt */ /* uint timeStamp */ /* uint80 answeredInRound */,
            ,
            ,

        ) = s_priceFeed.latestRoundData();
        uint8 decimals = s_priceFeed.decimals();
        return uint256(price) * (10 ** (18 - decimals)); //standardizes price to 18 decimals
    }

    function swapToStablecoin(uint256 amount) private nonReentrant {
        //swap ERC20 tokens for stablecoin on uniswap
        //need to approve uniswap to spend ERC20 tokens
        uint256 currentPrice = getLatestPrice();

        uint256 minAmoutOut = (amount * currentPrice * 98) / 100; //98% of the current price

        IERC20(s_erc20Token).approve(address(s_uniswapRouter), amount);
        TransferHelper.safeTransferFrom(
            s_erc20Token,
            msg.sender,
            address(this),
            amount
        );

        s_erc20Balance -= amount;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: s_erc20Token,
                tokenOut: s_stablecoin,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: minAmoutOut,
                sqrtPriceLimitX96: 0
            });
        s_uniswapRouter.exactInputSingle(params);

        uint256 amountRecieved = IERC20(s_stablecoin).balanceOf(address(this));
        s_stablecoinBalance += amountRecieved;

        emit SwapExecuted(amount, amountRecieved);
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (!s_isTSLActive) {
            upkeepNeeded = false;
            return (upkeepNeeded, performData);
        }
        // Implement logic to check if TSL conditions are met
        uint256 currentPrice = getLatestPrice();
        bool triggerSell = false;
        bool updateThreshold = false;
        uint256 newThreshold = 0;

        //calculates the actual price based on the threshold
        uint256 oldCurrentPrice = s_tslThreshold * 100 / (100-s_trailAmount);

        //determines the price that is 1% higher than the old stored price
        uint256 onePercentHigher = oldCurrentPrice*101/100;
        //if new price is less than the current threshold then trigger TSL
        if (currentPrice < s_tslThreshold) {
            //trigger TSL
            triggerSell = true;
        }
        
        else if (currentPrice > onePercentHigher) {
            updateThreshold = true;
            newThreshold = currentPrice * (100 - s_trailAmount) / 100;
        }

        performData = abi.encode(triggerSell, updateThreshold, newThreshold);
        upkeepNeeded = triggerSell || updateThreshold;
        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        // Implement logic to perform TSL (e.g., swap to stablecoin) when conditions are met
        (bool triggerSell, bool updateThreshold, uint256 newThreshold) = abi
            .decode(performData, (bool, bool, uint256));
        if (triggerSell) {
            swapToStablecoin(s_erc20Balance);
            //call trigger function to sell on uniswap
        } else if (updateThreshold) {
            //call updateThreshold function to update the threshold
            updateTSLThreshold(newThreshold);
        }
    }

    // View functions for contract interaction and frontend integration
    function getERC20Balance() public view returns (uint256) {
        return s_erc20Balance;
    }

    function getTSLThreshold() public view returns (uint256) {
        return s_tslThreshold;
    }

    function isTSLActive() public view returns (bool) {
        return s_isTSLActive;
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

    function getTrailAmount() public view returns (uint256) {
        return s_trailAmount;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
