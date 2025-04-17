// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.27;

// import "forge-std/Test.sol";
// import "../src/Dex.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// // Mock ERC20 Token for Testing
// contract MockERC20 is ERC20 {
//     constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
//         _mint(msg.sender, initialSupply); // Mint initial supply to deployer
//     }
// }

// // Dex Test Contract
// contract DexTest is Test {
//     Dex public dex; // Instance of the DEX contract
//     MockERC20 public token1; // Mock Token1 (e.g., USDC)
//     MockERC20 public token2; // Mock Token2 (e.g., DAI)
//     address public owner; // Owner address (deployer)
//     address public user; // External user for testing

//     uint256 public initialSupply = 1_000_000 ether; // Initial token supply (1M with 18 decimals)

//     /// @dev Foundry setup function, runs before each test
//     function setUp() public {
//         // Set up test accounts
//         owner = address(this); // Contract itself is the owner
//         user = address(0x123); // Example external user

//         // Deploy mock tokens
//         token1 = new MockERC20("Mock Token 1", "TKN1", initialSupply);
//         token2 = new MockERC20("Mock Token 2", "TKN2", initialSupply);

//         // Deploy the Dex contract
//         dex = new Dex(address(token1), address(token2));

//         // Allocate tokens to user and approve the DEX contract
//         token1.transfer(user, 100_000 ether); // Transfer 100,000 TKN1 to user
//         token2.transfer(user, 100_000 ether); // Transfer 100,000 TKN2 to user

//         // Approve DEX for owner's tokens
//         token1.approve(address(dex), type(uint256).max); // Owner approves max allowance for token1
//         token2.approve(address(dex), type(uint256).max); // Owner approves max allowance for token2

//         // Simulate user's approvals for DEX
//         vm.prank(user);
//         token1.approve(address(dex), type(uint256).max); // User approves max allowance for token1
//         vm.prank(user);
//         token2.approve(address(dex), type(uint256).max); // User approves max allowance for token2
//     }

//     /// @dev Test adding initial liquidity to the pool
//     function testAddLiquidityInitial() public {
//         uint256 token1Amount = 10_000 ether; // Adding 10,000 token1
//         uint256 token2Amount = 20_000 ether; // Adding 20,000 token2

//         // Add liquidity from the owner account
//         dex.addLiquidity(token1Amount, token2Amount);

//         // Verify the reserves are updated correctly
//         (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
//         assertEq(token1Reserve, token1Amount, "Token1 reserve mismatch");
//         assertEq(token2Reserve, token2Amount, "Token2 reserve mismatch");

//         // Verify the LP tokens minted are correct (equal to token1Amount for the first provider)
//         assertEq(dex.lpTokens(owner), token1Amount, "LP token minting mismatch for initial liquidity");

//         // Verify total liquidity matches the minted LP tokens
//         assertEq(dex.totalLiquidity(), token1Amount, "Total liquidity mismatch for initial liquidity");
//     }

//     /// @dev Test adding liquidity after the initial liquidity is provided
//     function testAddLiquiditySubsequent() public {
//         // Add initial liquidity
//         uint256 initialToken1Amount = 10_000 ether;
//         uint256 initialToken2Amount = 20_000 ether;
//         dex.addLiquidity(initialToken1Amount, initialToken2Amount);

//         // Simulate user adding subsequent liquidity
//         vm.prank(user);
//         uint256 userToken1Amount = 5_000 ether; // User contributes 5,000 token1
//         uint256 userToken2Amount = 10_000 ether; // User contributes 10,000 token2
//         dex.addLiquidity(userToken1Amount, userToken2Amount);

//         // Verify the reserves are updated correctly
//         (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
//         assertEq(token1Reserve, 15_000 ether, "Token1 reserve mismatch after subsequent liquidity");
//         assertEq(token2Reserve, 30_000 ether, "Token2 reserve mismatch after subsequent liquidity");

//         // Verify the LP tokens minted for the user
//         uint256 userLpTokens = dex.lpTokens(user);
//         assertEq(userLpTokens, 5_000 ether, "LP token minting mismatch for subsequent liquidity");

//         // Verify total liquidity is updated correctly
//         uint256 totalLiquidity = dex.totalLiquidity();
//         assertEq(totalLiquidity, 15_000 ether, "Total liquidity mismatch after subsequent liquidity");
//     }

//     /// @dev Test adding liquidity with invalid ratios (should revert)
//     function testAddLiquidityInvalidRatio() public {
//         // Add initial liquidity
//         uint256 initialToken1Amount = 10_000 ether;
//         uint256 initialToken2Amount = 20_000 ether;
//         dex.addLiquidity(initialToken1Amount, initialToken2Amount);

//         // Simulate user trying to add liquidity with mismatched ratio
//         vm.prank(user);
//         uint256 invalidToken1Amount = 5_000 ether; // Valid ratio would require 10,000 token2
//         uint256 invalidToken2Amount = 9_000 ether; // This is an incorrect ratio

//         vm.expectRevert("Invalid token ratio");
//         dex.addLiquidity(invalidToken1Amount, invalidToken2Amount);
//     }

//     /// @dev Test adding liquidity with zero amounts (should revert)
//     function testAddLiquidityZeroAmounts() public {
//         // Try adding liquidity with zero amounts
//         vm.expectRevert("Invalid input amounts");
//         dex.addLiquidity(0, 10_000 ether);

//         vm.expectRevert("Invalid input amounts");
//         dex.addLiquidity(10_000 ether, 0);
//     }
// }
