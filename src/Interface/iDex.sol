// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface iDex {
    error Dex__TokenAmountMismatch();
    error Dex__AmountIsZero();
    error Dex__InvalidReserve();
    error Dex__TokenAddressCannotBeZero();
    error Dex__InvalidToken();
    error Dex__InsufficientInitialLiquidity();
    error Dex__InvalidTokenRatio();
    error Dex__InsufficientLPtokens();
    error Dex__InsufficientLiquidityAfterWithdrawal();
    error Dex__InvalidInputAmount();
    error Dex__InsufficientLiquidity();
    error Dex__SlippageExceeded();
    error Dex__InvalidTokensAmount();
    error Dex__UnbalancedPool();
    error Dex__InsufficientLPBalance();
    error Dex__InvalidLPTokenAmount();


    event LiquidityAdded(
        address indexed provider,
        uint256 token1Amount,
        uint256 token2Amount
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 lpTokensToBurn,
        uint256 token1Amount,
        uint256 token2Amount
    );
    event TokenSwapped(
        address indexed swapper,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event FeeUpdated(uint256 newFeeNumerator);
}
