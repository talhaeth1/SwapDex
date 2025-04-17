// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// contract Dex is Ownable, ReentrancyGuard {
//     using SafeERC20 for IERC20;

//     struct LiquidityPool {
//         uint256 token1Reserve;
//         uint256 token2Reserve;
//     }

//     address public token1;
//     address public token2;
//     LiquidityPool public pool;
//     mapping(address lpAddress => uint256 lpAmount) public lpTokens;
//     uint256 public totalLiquidity;

//     uint256 public feeNumerator = 997;
//     uint256 public constant FEE_DENOMINATOR = 1000;

//     event LiquidityAdded(address indexed provider, uint256 token1Amount, uint256 token2Amount);
//     event LiquidityRemoved(address indexed provider, uint256 token1Amount, uint256 token2Amount);
//     event TokenSwapped(address indexed swapper, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
//     event FeeUpdated(uint256 newFeeNumerator);

//     constructor(address _token1, address _token2) Ownable(msg.sender) {
//         require(_token1 != address(0) && _token2 != address(0), "Token address cannot be zero");
//         token1 = _token1;
//         token2 = _token2;
//     }

//     modifier validToken(address token) {
//         require((token == token1 || token == token2) && token != address(0), "Invalid token");
//         _;
//     }

//     function addLiquidity(uint256 token1Amount, uint256 token2Amount)
//         external
//         nonReentrant
//     {
//         if (totalLiquidity == 0) {
//             require(token1Amount > 1000 && token2Amount > 1000, "Insufficient initial liquidity");
//             pool.token1Reserve = token1Amount;
//             pool.token2Reserve = token2Amount;
//             totalLiquidity = token1Amount;
//         } else {
//             require(
//                 token1Amount * pool.token2Reserve == token2Amount * pool.token1Reserve,
//                 "Invalid token ratio"
//             );
//             pool.token1Reserve += token1Amount;
//             pool.token2Reserve += token2Amount;
//         }

//         uint256 lpTokensToMint = (token1Amount * totalLiquidity) / pool.token1Reserve;
//         lpTokens[msg.sender] += lpTokensToMint;
//         totalLiquidity += lpTokensToMint;

//         IERC20(token1).safeTransferFrom(msg.sender, address(this), token1Amount);
//         IERC20(token2).safeTransferFrom(msg.sender, address(this), token2Amount);

//         emit LiquidityAdded(msg.sender, token1Amount, token2Amount);
//     }

//     function removeLiquidity(uint256 lpTokenAmount) external nonReentrant {
//         require(lpTokens[msg.sender] >= lpTokenAmount, "Insufficient LP tokens");

//         uint256 token1Amount = (lpTokenAmount * pool.token1Reserve) / totalLiquidity;
//         uint256 token2Amount = (lpTokenAmount * pool.token2Reserve) / totalLiquidity;

//         require(
//             pool.token1Reserve - token1Amount > 1000 && pool.token2Reserve - token2Amount > 1000,
//             "Insufficient liquidity after withdrawal"
//         );

//         pool.token1Reserve -= token1Amount;
//         pool.token2Reserve -= token2Amount;
//         lpTokens[msg.sender] -= lpTokenAmount;
//         totalLiquidity -= lpTokenAmount;

//         IERC20(token1).safeTransfer(msg.sender, token1Amount);
//         IERC20(token2).safeTransfer(msg.sender, token2Amount);

//         emit LiquidityRemoved(msg.sender, token1Amount, token2Amount);
//     }

//     function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
//         external
//         nonReentrant
//         validToken(tokenIn)
//     {
//         require(amountIn > 0, "Invalid input amount");

//         uint256 tokenInReserve = (tokenIn == token1) ? pool.token1Reserve : pool.token2Reserve;
//         uint256 tokenOutReserve = (tokenIn == token1) ? pool.token2Reserve : pool.token1Reserve;

//         require(tokenInReserve > 1000 && tokenOutReserve > 1000, "Insufficient liquidity");

//         address tokenOut = (tokenIn == token1) ? token2 : token1;

//         uint256 amountInWithFee = amountIn * feeNumerator;
//         uint256 numerator = amountInWithFee * tokenOutReserve;
//         uint256 denominator = (tokenInReserve * FEE_DENOMINATOR) + amountInWithFee;
//         uint256 amountOut = numerator / denominator;

//         require(amountOut >= minAmountOut, "Slippage exceeded");

//         if (tokenIn == token1) {
//             pool.token1Reserve += amountIn;
//             pool.token2Reserve -= amountOut;
//         } else {
//             pool.token2Reserve += amountIn;
//             pool.token1Reserve -= amountOut;
//         }

//         IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
//         IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

//         emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
//     }


//     /*** VIEW FUNCTIONS ***/

//     // Get Pool Reserves
//     function getReserves() external view returns (uint256 token1Reserve, uint256 token2Reserve) {
//         return (pool.token1Reserve, pool.token2Reserve);
//     }
// }
