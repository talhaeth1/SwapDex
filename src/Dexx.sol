// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {iDex} from "./Interface/iDex.sol";

contract Dex is Ownable, ReentrancyGuard, iDex {
    using SafeERC20 for IERC20;

    struct LiquidityPool {
        uint256 token1Reserve;
        uint256 token2Reserve;
    }

    address public token1;
    address public token2;
    LiquidityPool public pool;
    uint256 public totalLiquidity;
    uint256 public feeNumerator = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    mapping(address lpAddress => uint256 lpAmount) public lpTokens;

    /// @notice Constructor for the DEX contract
    /// @dev Initializes the contract with the provided token addresses
    constructor(address _token1, address _token2) Ownable(msg.sender) {
        if (!(_token1 != address(0) && _token2 != address(0))) {
            revert Dex__TokenAddressCannotBeZero();
        }
        token1 = _token1;
        token2 = _token2;
    }

    /// @notice Modifier to validate token address
    /// @param token Address of the token
    modifier validToken(address token) {
        if (!((token == token1 || token == token2) && token != address(0))) {
            revert Dex__InvalidToken();
        }
        _;
    }

    /// @notice Add liquidity to the DEX pool
    /// @dev Allows users to provide liquidity by depositing both tokens in the correct ratio
    /// @param token1Amount Amount of token1 to deposit
    /// @param token2Amount Amount of token2 to deposit
    /// @custom:security nonReentrant modifier prevents reentrancy attacks
    /// @custom:security Checks-Effects-Interactions pattern followed
    /// @custom:security Validates token balances match reserves before updates
    /// @custom:security Requires minimum initial liquidity of 1000 tokens
    /// @custom:security Enforces correct token ratio for subsequent deposits
    /// @custom:security Uses SafeERC20 for token transfers
    function addLiquidity(
        uint256 token1Amount,
        uint256 token2Amount
    ) external nonReentrant {
        if (token1Amount == 0 && token2Amount == 0) {
            revert Dex__InvalidTokensAmount();
        }

        //check if the actual token balance match the tracked reserves
        uint256 actualToken1Balance = IERC20(token1).balanceOf(address(this));
        uint256 actualToken2Balace = IERC20(token2).balanceOf(address(this));

        if (
            actualToken1Balance != pool.token1Reserve ||
            actualToken2Balace != pool.token2Reserve
        ) {
            revert Dex__UnbalancedPool();
        }

        if (totalLiquidity == 0) {
            if (!(token1Amount > 1000 && token2Amount > 1000)) {
                revert Dex__InsufficientInitialLiquidity();
            }
            //Initilize pool reserves and mint lp tokens
            pool.token1Reserve = token1Amount;
            pool.token2Reserve = token2Amount;

            // Mint LP tokens equal to token1Amount for the first provider
            lpTokens[msg.sender] = token1Amount;
            totalLiquidity = token1Amount; // Set total liquidity to token1Amount
        } else {
            //first capture the reserves before updating them
            uint256 currentToken1Reserve = pool.token1Reserve;
            uint256 currentToken2Reserve = pool.token2Reserve;

            //check if the input amount matches the current pool ratio
            if (
                !(token1Amount * currentToken2Reserve ==
                    token2Amount * currentToken1Reserve)
            ) {
                revert Dex__InvalidTokenRatio();
            }

            // Calculate LP tokens to mint
            uint256 lpTokensToMint = (token1Amount * totalLiquidity) /
                currentToken1Reserve;

            // Update the pool reserves
            pool.token1Reserve += token1Amount;
            pool.token2Reserve += token2Amount;

            // Mint LP tokens proportional to contribution
            lpTokens[msg.sender] += lpTokensToMint;
            totalLiquidity += lpTokensToMint;
        }

        // Transfer tokens from the sender
        IERC20(token1).safeTransferFrom(
            msg.sender,
            address(this),
            token1Amount
        );
        IERC20(token2).safeTransferFrom(
            msg.sender,
            address(this),
            token2Amount
        );

        emit LiquidityAdded(msg.sender, token1Amount, token2Amount);
    }

    /// @notice Remove liquidity from the DEX pool
    /// @dev Allows users to withdraw both tokens in the correct ratio
    /// @param lpTokensToBurn Amount of LP tokens to burn
    /// @custom:security nonReentrant modifier prevents reentrancy attacks
    /// @custom:security Checks-Effects-Interactions pattern followed
    /// @custom:security Validates token balances match reserves before updates
    /// @custom:security Requires minimum initial liquidity of 1000 tokens
    /// @custom:security Uses SafeERC20 for token transfers
    function removeLiquidity(uint256 lpTokensToBurn) external nonReentrant {
        //Ensure user is attempting to burn a valid amount LP tokens
        if(lpTokensToBurn == 0){
            revert Dex__InvalidLPTokenAmount();
        }
        // Check if user has sufficient LP tokens
        if (lpTokens[msg.sender] < lpTokensToBurn) {
            revert Dex__InsufficientLPBalance();
        }

        //Verify that pool reserves are consistent with the tracked reserves
        uint256 actualToken1Balance = IERC20(token1).balanceOf(address(this));
        uint256 actualToken2Balace = IERC20(token2).balanceOf(address(this));

        if (
            actualToken1Balance != pool.token1Reserve ||
            actualToken2Balace != pool.token2Reserve
        ) {
            revert Dex__UnbalancedPool();
        }

        // Ensure the pool will still have sufficient liquidity after withdrawal
        uint256 token1Amount = (lpTokensToBurn * pool.token1Reserve) /
            totalLiquidity;
        uint256 token2Amount = (lpTokensToBurn * pool.token2Reserve) /
            totalLiquidity;

        // Check if the withdrawal will leave sufficient liquidity
        if (
            pool.token1Reserve < token1Amount ||
            pool.token2Reserve < token2Amount
        ) {
            revert Dex__InsufficientLiquidityAfterWithdrawal();
        }

        // Update pool reserves and total liquidity
        pool.token1Reserve -= token1Amount;
        pool.token2Reserve -= token2Amount;
        totalLiquidity -= lpTokensToBurn;

        // Burn LP tokens from the user balance
        lpTokens[msg.sender] -= lpTokensToBurn;

        // Transfer tokens to the user
        IERC20(token1).safeTransfer(msg.sender, token1Amount);
        IERC20(token2).safeTransfer(msg.sender, token2Amount);

        emit LiquidityRemoved(
            msg.sender,
            lpTokensToBurn,
            token1Amount,
            token2Amount
        );
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant validToken(tokenIn) {
        if (!(amountIn > 0)) {
            revert Dex__InvalidInputAmount();
        }

        uint256 tokenInReserve = (tokenIn == token1)
            ? pool.token1Reserve
            : pool.token2Reserve;
        uint256 tokenOutReserve = (tokenIn == token1)
            ? pool.token2Reserve
            : pool.token1Reserve;

        if (!(tokenInReserve > 1000 && tokenOutReserve > 1000)) {
            revert Dex__InsufficientLiquidity();
        }

        address tokenOut = (tokenIn == token1) ? token2 : token1;

        uint256 amountInWithFee = amountIn * feeNumerator;
        uint256 numerator = amountInWithFee * tokenOutReserve;
        uint256 denominator = (tokenInReserve * FEE_DENOMINATOR) +
            amountInWithFee;
        uint256 amountOut = numerator / denominator;

        if (!(amountOut >= minAmountOut)) {
            revert Dex__SlippageExceeded();
        }

        if (tokenIn == token1) {
            pool.token1Reserve += amountIn;
            pool.token2Reserve -= amountOut;
        } else {
            pool.token2Reserve += amountIn;
            pool.token1Reserve -= amountOut;
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    /*** VIEW FUNCTIONS ***/

    // Get Pool Reserves
    function getReserves()
        external
        view
        returns (uint256 token1Reserve, uint256 token2Reserve)
    {
        return (pool.token1Reserve, pool.token2Reserve);
    }
}
