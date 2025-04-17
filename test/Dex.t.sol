// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Dex} from "../src/Dexx.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {iDex} from "../src/Interface/iDex.sol";

contract DexTest is Test, iDex {
    Dex public dex;
    MockUSDC public token1; //USDC
    MockUSDC public token2; //DAI

    address public owner;
    address public USER = makeAddr("user");
    uint256 public initialSupply = 1_000_000 ether; // 1 million tokens with 18 decimals

    /// @dev Foundry setup function, runs before each test
    function setUp() public {
        owner = address(this); //the contract itself is the owner

        // Deploy mock tokens
        token1 = new MockUSDC("Mock Token 1", "MT1", initialSupply);
        token2 = new MockUSDC("Mock Token 2", "MT2", initialSupply);

        // Deploy DEX
        dex = new Dex(address(token1), address(token2));

        //Allocate initial tokens to user for testing
        token1.transfer(USER, 100_000 ether);
        token2.transfer(USER, 100_000 ether);

        // Approve DEX for owner's tokens
        token1.approve(address(dex), type(uint256).max); // Owner approves max allowance for token1
        token2.approve(address(dex), type(uint256).max); // Owner approves max allowance for token2

        // Approve DEX for user's tokens
        vm.startPrank(USER); // Set the next transactions as `user`
        token1.approve(address(dex), type(uint256).max); // User approves max allowance for token1
        token2.approve(address(dex), type(uint256).max); // User approves max allowance for token2
        vm.stopPrank(); // End user session
    }

    /*    modifier Add_initialLiquidity(
        uint256 _initialToken1Amount,
        uint256 _initialToken2Amount
    ) {
        if (_initialToken1Amount == 0 || _initialToken2Amount == 0) {
            revert Dex__InvalidTokensAmount();
        }
        _;
    } */

    /// @dev Test adding initial liquidity to the pool
    function test_Liquidity() public {
        uint256 token1_amount = 10_000 ether;
        uint256 token2_amount = 10_000 ether;

        //Add liquidity from the owner account
        dex.addLiquidity(token1_amount, token2_amount);

        //verify the reserves are updated correctly
        (uint256 token1_reserve, uint256 token2_reserve) = dex.getReserves();

        assertEq(token1_reserve, token1_amount, "token 1 reserve mismatch");
        assertEq(token2_reserve, token2_amount, "token 2 reserve mismatch");

        //verify the lp tokens minted are correct (equal to token1_amount for the first provider)
        assertEq(
            dex.lpTokens(owner),
            token1_amount,
            "lp tokens minting mismatch for initial liquidity"
        );

        //varify the total liquidity matches the minted lp tokens
        assertEq(
            dex.totalLiquidity(),
            token1_amount,
            "total liquidity mismatch for initial liquidity"
        );
    }

    function test_AddLiquiditySubsequent() public {
        // Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Simulate user adding subsequent liquidity
        vm.startPrank(USER); // Set user as the caller
        uint256 userToken1Amount = 5_000 ether; // User contributes 5,000 token1
        uint256 userToken2Amount = 10_000 ether; // User contributes 10,000 token2
        dex.addLiquidity(userToken1Amount, userToken2Amount);
        vm.stopPrank();

        // Verify the reserves are updated correctly
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(
            token1Reserve,
            15_000 ether,
            "Token1 reserve mismatch after subsequent liquidity"
        );
        assertEq(
            token2Reserve,
            30_000 ether,
            "Token2 reserve mismatch after subsequent liquidity"
        );

        // Calculate the expected LP tokens minted for the user
        uint256 totalLiquidityBefore = 10_000 ether; // Total liquidity before user adds
        uint256 userLpTokensExpected = (userToken1Amount *
            totalLiquidityBefore) / initialToken1Amount;

        // Verify the LP tokens minted for the user
        uint256 userLpTokens = dex.lpTokens(USER);
        assertEq(
            userLpTokens,
            userLpTokensExpected,
            "LP token minting mismatch for subsequent liquidity"
        );

        // Verify total liquidity is updated correctly
        uint256 totalLiquidity = dex.totalLiquidity();
        uint256 expectedTotalLiquidity = totalLiquidityBefore +
            userLpTokensExpected;
        assertEq(
            totalLiquidity,
            expectedTotalLiquidity,
            "Total liquidity mismatch after subsequent liquidity"
        );
    }

    function test_RevertAddLiquidityWithZeroAmount() public {
        // case 1: zero token1Amount, valid token2Amount
        vm.expectRevert();
        dex.addLiquidity(0, 10_000 ether);

        // case 2: valid token1Amount, zero token2Amount
        vm.expectRevert();
        dex.addLiquidity(10_000 ether, 0);

        // case 3: zero token1Amount, zero token2Amount
        vm.expectRevert();
        dex.addLiquidity(0, 0);
    }

    function test_AddLiquidityWithMismatchedRatios() public {
        // Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Simulate user trying to add liquidity with mismatched ratio
        vm.startPrank(USER);

        //case 1: Too much token1, too little token2
        uint256 mismatchedToken1Amount = 5_000 ether; // Valid ratio would require 10,000 token2
        uint256 mismatchedToken2Amount = 9_000 ether; // This is an incorrect ratio
        vm.expectRevert();
        dex.addLiquidity(mismatchedToken1Amount, mismatchedToken2Amount);

        //case 2: Too little token1, too much token2
        mismatchedToken1Amount = 9_000 ether; // Valid ratio would require 10,000 token2
        mismatchedToken2Amount = 5_000 ether; // This is an incorrect ratio
        vm.expectRevert();
        dex.addLiquidity(mismatchedToken1Amount, mismatchedToken2Amount);

        vm.stopPrank();
    }

    function test_AddLiquidityToUnbalancedPool() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        //Manually transfer token1 to the dex contract to create a unbalanced state
        token1.transfer(address(dex), 5_000 ether);

        //Pool reserves are now unbalanced (15k token1, 20k token2)

        //Attempts to add liquidity with the original ratios (1:2)
        vm.startPrank(USER);
        uint256 userToken1Amount = 5_000 ether;
        uint256 userToken2Amount = 10_000 ether;
        // vm.expectRevert();
        vm.expectRevert(Dex__UnbalancedPool.selector);
        dex.addLiquidity(userToken1Amount, userToken2Amount);
        vm.stopPrank();
    }

    function test_AddLiquidityWithMinimalAmounts() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Simulate adding minimal token amounts
        vm.startPrank(USER);
        uint256 minimalToken1Amount = 1; // Minimal token1 amount (1 wei)
        uint256 minimalToken2Amount = 2; // Minimal token2 amount (2 wei)

        // Expect this to pass because ratios are still valid
        dex.addLiquidity(minimalToken1Amount, minimalToken2Amount);
        vm.stopPrank();

        // Verify the reserves are updated correctly
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(
            token1Reserve,
            initialToken1Amount + minimalToken1Amount,
            "Token1 reserve mismatch"
        );
        assertEq(
            token2Reserve,
            initialToken2Amount + minimalToken2Amount,
            "Token2 reserve mismatch"
        );

        // Verify LP tokens minted for the user
        uint256 userLpTokens = dex.lpTokens(USER);
        uint256 expectedLpTokens = (minimalToken1Amount * initialToken1Amount) /
            initialToken1Amount; // This simplifies to `minimalToken1Amount`
        assertEq(
            userLpTokens,
            expectedLpTokens,
            "LP token minting mismatch for minimal liquidity"
        );

        // Verify total liquidity is updated correctly
        uint256 expectedTotalLiquidity = initialToken1Amount +
            minimalToken1Amount; // Since LP tokens are tied to token1
        assertEq(
            dex.totalLiquidity(),
            expectedTotalLiquidity,
            "Total liquidity mismatch"
        );
    }

    function test_AddMinimalSingleSidedContribution() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Simulate adding minimal amount for token1, calculating the corresponding amount for token2
        vm.startPrank(USER);
        uint256 minimalToken1Amount = 1; // Minimal token1 amount (1 wei)
        uint256 proportionalToken2Amount = (minimalToken1Amount *
            initialToken2Amount) / initialToken1Amount;

        //Add Liquidity
        dex.addLiquidity(minimalToken1Amount, proportionalToken2Amount);
        vm.stopPrank();

        //Verify the reserves are updated correctly
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(
            token1Reserve,
            initialToken1Amount + minimalToken1Amount,
            "Token1 reserve mismatch"
        );
        assertEq(
            token2Reserve,
            proportionalToken2Amount + initialToken2Amount,
            "Token2 reserve mismatch"
        );

        //Verify lp tokens minted for the user
        uint256 userLpTokens = dex.lpTokens(USER);
        uint256 expectedLpTokens = (minimalToken1Amount *
            dex.totalLiquidity()) / initialToken1Amount;
        assertEq(
            userLpTokens,
            expectedLpTokens,
            "LP token minting mismatch for minimal liquidity"
        );
    }

    function test_AddLargeAfterMinimalLiquidity() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        //Add minimal amount first
        vm.startPrank(USER);
        uint256 minimalToken1Amount = 1; // Minimal token1 amount (1 wei)
        uint256 minimalToken2Amount = 2; // Minimal token1 amount (2 wei)

        dex.addLiquidity(minimalToken1Amount, minimalToken2Amount);

        //Add large amount of liquidity
        uint256 largeToken1Amount = 1_000 ether;
        uint256 largeToken2Amount = 2_000 ether;
        dex.addLiquidity(largeToken1Amount, largeToken2Amount);
        vm.stopPrank();

        //Verif the reserves are updated correctly
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(
            token1Reserve,
            initialToken1Amount + minimalToken1Amount + largeToken1Amount,
            "Token1 reserve mismatch after large contribution"
        );
        assertEq(
            token2Reserve,
            initialToken2Amount + minimalToken2Amount + largeToken2Amount,
            "Token2 reserve mismatch after large contribution"
        );
    }

    function test_MiliciousTokenTransfer() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        //Verify initial reserves
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");

        //Malicious transfer of extra token1 to the contract
        token1.transfer(address(dex), 1_000 ether);

        //Verify that the actual token balance is now greater than the tracked reserves
        uint256 actualToken1Balance = token1.balanceOf(address(dex));
        assertEq(
            actualToken1Balance,
            token1Reserve + 1_000 ether,
            "Actual token1 balance mismatch after millicious transfer"
        );

        //Attempts to add liquidity with the original ratios (1:2) shoud now fail
        vm.startPrank(USER);
        uint256 userToken1Amount = 1_000 ether;
        uint256 userToken2Amount = 2_000 ether;
        vm.expectRevert(Dex__UnbalancedPool.selector);
        dex.addLiquidity(userToken1Amount, userToken2Amount);
        vm.stopPrank();
    }

    function test_ManipulateBothTokensWithMatchingRatios() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        Add_initialLiquidity(initialToken1Amount, initialToken2Amount);

        //Verify initial reserves
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");

        //Malicious transfer of extra tokens with matching ratio
        token1.transfer(address(dex), 5_000 ether);
        token2.transfer(address(dex), 10_000 ether);

        //verify the actual balance is now greater than the tracked reserves
        uint256 actualToken1Balance = token1.balanceOf(address(dex));
        uint256 actualToken2Balance = token2.balanceOf(address(dex));
        assertEq(
            actualToken1Balance,
            token1Reserve + 5_000 ether,
            "Actual token1 balance mismatch after millicious transfer"
        );
        assertEq(
            actualToken2Balance,
            token2Reserve + 10_000 ether,
            "Actual token2 balance mismatch after millicious transfer"
        );

        //Attempts to add liquidity with the original ratios (1:2) shoud now fail
        vm.startPrank(USER);
        uint256 userToken1Amount = 1_000 ether;
        uint256 userToken2Amount = 2_000 ether;
        vm.expectRevert(Dex__UnbalancedPool.selector);
        dex.addLiquidity(userToken1Amount, userToken2Amount);
        vm.stopPrank();

        //attemps to swap also fail
    }

    function test_ExtremeImbalanceOfBothTokens() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        Add_initialLiquidity(initialToken1Amount, initialToken2Amount);

        //verify initial reserves
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");

        //Malicious transfer of extreme amounts of both tokens
        token1.transfer(address(dex), 100_000 ether);
        token2.transfer(address(dex), 200_000 ether);

        //verify the actual balance is now greater than the tracked reserves
        uint256 actualToken1Balance = token1.balanceOf(address(dex));
        uint256 actualToken2Balance = token2.balanceOf(address(dex));
        assertEq(
            actualToken1Balance,
            token1Reserve + 100_000 ether,
            "Actual token1 balance mismatch after millicious transfer"
        );
        assertEq(
            actualToken2Balance,
            token2Reserve + 200_000 ether,
            "Actual token2 balance mismatch after millicious transfer"
        );

        //Attempts to add liquidity with the original ratios (1:2) shoud now fail
        vm.startPrank(USER);
        uint256 userToken1Amount = 1_000 ether;
        uint256 userToken2Amount = 2_000 ether;
        vm.expectRevert(Dex__UnbalancedPool.selector);
        dex.addLiquidity(userToken1Amount, userToken2Amount);
        vm.stopPrank();

        // Attempting to swap should also revert
    }

    function test_MultipleMaliciousTransfers() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        Add_initialLiquidity(initialToken1Amount, initialToken2Amount);

        //verify initial reserves
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");

        //Perform multiple malicious transfers
        token1.transfer(address(dex), 1_000 ether);
        token2.transfer(address(dex), 2_000 ether);
        token1.transfer(address(dex), 3_000 ether);
        token2.transfer(address(dex), 4_000 ether);

        //Verify actual balances
        uint256 actualToken1Balance = token1.balanceOf(address(dex));
        uint256 actualToken2Balance = token2.balanceOf(address(dex));
        assertEq(
            actualToken1Balance,
            token1Reserve + 4_000 ether,
            "Actual token1 balance mismatch after millicious transfer"
        );
        assertEq(
            actualToken2Balance,
            token2Reserve + 6_000 ether,
            "Actual token2 balance mismatch after millicious transfer"
        );

        //Attemptig any operation should fail
        vm.startPrank(USER);
        vm.expectRevert(Dex__UnbalancedPool.selector);
        dex.addLiquidity(1_000 ether, 2_000 ether);
        vm.stopPrank();
    }

    /*
      ---------------------------
      -  Remove liquidity Tests -
      ---------------------------
    */

    ///@dev Remove full liquidity
    function test_RemoveFullLiquidity() public {
        // Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Verify initial reserves and total liquidity
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        uint256 totalLiquidity = dex.totalLiquidity();
        assertEq(
            totalLiquidity,
            initialToken1Amount,
            "Total liquidity mismatch"
        );

        //Verify user LP balance before removal
        uint256 userLpTokens = dex.lpTokens(address(this));
        assertEq(userLpTokens, totalLiquidity, "LP token balance mismatch");

        // Remove all liquidity (burn all LP tokens)
        dex.removeLiquidity(userLpTokens);

        // Verify that reserves are now zero
        (uint256 updatedToken1Reserve, uint256 updatedToken2Reserve) = dex
            .getReserves();
        assertEq(
            updatedToken1Reserve,
            0,
            "Token1 reserve mismatch after full removal"
        );
        assertEq(
            updatedToken2Reserve,
            0,
            "Token2 reserve mismatch after full removal"
        );

        // Verify total liquidity is zero
        uint256 updatedTotalLiquidity = dex.totalLiquidity();
        assertEq(
            updatedTotalLiquidity,
            0,
            "Total liquidity mismatch after full removal"
        );

        // Verify LP token balance is zero
        uint256 updatedUserLpTokens = dex.lpTokens(address(this));
        assertEq(
            updatedUserLpTokens,
            0,
            "LP token balance mismatch after full removal"
        );
    }

    ///@dev Remove partial liquidity
    function test_RemovePartialLiquidity() public {
        // Add initial liquidity (valid ratio)
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        Add_initialLiquidity(initialToken1Amount, initialToken2Amount);

        //verify initial reserves
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");

        //verify total liquidity and lp tokens balance
        uint256 totalLiquidity = dex.totalLiquidity();
        assertEq(
            totalLiquidity,
            initialToken1Amount,
            "Total liquidity mismatch"
        );

        uint256 ownerLpTokens = dex.lpTokens(address(this));
        assertEq(ownerLpTokens, initialToken1Amount, "LP tokens mismatch");

        //Remove liquidity (burn lp tokens)
        uint256 lpTokensToBurn = 5_000 ether; //Burn 5,000 LP tokens (50% of pool)
        dex.removeLiquidity(lpTokensToBurn);

        //verify the reserves are updated correctly
        (uint256 updatedToken1Reserve, uint256 updatedToken2Reserve) = dex
            .getReserves();
        uint256 expectedToken1Reserve = token1Reserve -
            (lpTokensToBurn * token1Reserve) /
            totalLiquidity;
        uint256 expectedToken2Reserve = token2Reserve -
            (lpTokensToBurn * token2Reserve) /
            totalLiquidity;

        assertEq(
            updatedToken1Reserve,
            expectedToken1Reserve,
            "updated token 1 reserves mismatch"
        );
        assertEq(
            updatedToken2Reserve,
            expectedToken2Reserve,
            "updated token 2 reserves mismatch"
        );

        //Verify updated LP token balance
        uint256 updatedOwnerLpTokens = dex.lpTokens(address(this));
        uint256 expectedLpTokens = ownerLpTokens - lpTokensToBurn;
        assertEq(
            updatedOwnerLpTokens,
            expectedLpTokens,
            "Updated LP tokens mismatch"
        );

        //Verify total liquidity is updated correctly
        uint256 updatedTotalLiquidity = dex.totalLiquidity();
        uint256 expectedTotalLiquidity = totalLiquidity - lpTokensToBurn;
        assertEq(
            updatedTotalLiquidity,
            expectedTotalLiquidity,
            "Updated total liquidity mismatch"
        );
    }

    /// @dev Remove Liquidity with Zero LP Tokens (Should Revert)
    function test_RemoveLiquidityWithoutLpTokens() public {
        // Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        //Simulate a user without LP tokens
        vm.startPrank(USER);

        //Attempts to remove liquidity without LP tokens
        uint256 lpTokensToBurn = 1_000 ether; //Burn 1,000 LP tokens (50% of pool)
        vm.expectRevert();
        dex.removeLiquidity(lpTokensToBurn);

        vm.stopPrank();
    }

    ///@dev Remove Liquidity Beyond Owned LP Tokens (Should Revert)
    function test_RemoveLiquidityInvalidAmount() public {
        // Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Verify initial LP tokens minted for the owner
        uint256 ownerLpTokens = dex.lpTokens(address(this));
        assertEq(
            ownerLpTokens,
            initialToken1Amount,
            "LP token balance mismatch"
        );

        //Attempts to remove more LP tokens than available (should revert)
        uint256 invalidLpTokensToBurn = ownerLpTokens + 20_000 ether; // More than owned
        vm.expectRevert(); //Dex__InsufficientLPBalance
        dex.removeLiquidity(invalidLpTokensToBurn);

        // Verify the state remains unchanged
        uint256 updatedLpTokens = dex.lpTokens(address(this));
        assertEq(
            updatedLpTokens,
            ownerLpTokens,
            "LP token balance mismatch after failed removal"
        );
        (uint256 token1reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(
            token1reserve,
            initialToken1Amount,
            "Token1 reserve mismatch after failed removal"
        );
        assertEq(
            token2Reserve,
            initialToken2Amount,
            "Token2 reserve mismatch after failed removal"
        );
    }

    ///@dev Remove Liquidity from an Empty Pool (Should Revert)
    function test_RemoveLiquidityFromEmptyPool() public {
        //Attempts to remove liquidity from an empty pool
        uint256 lpTokensToBurn = 1_000 ether; //Burn 1,000 LP tokens (50% of pool)
        vm.expectRevert(); //Pool empty (Dex__InsufficientLPBalance)
        dex.removeLiquidity(lpTokensToBurn);
    }

    /// @notice This tests the behavior when pool reserves are manipulated (e.g., via direct token transfers to the contract) before attempting liquidity removal.
    /// @dev Ensure that the removeLiquidity function reverts when the pool reserves are manipulated and become unbalanced before the liquidity removal attempt.

    function test_RemoveLiquidityWithUnbalancedPool() public {
        // Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        //Verify the initial reserves and LP tokens minted
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        uint256 ownerLpTokens = dex.lpTokens(address(this));
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");
        assertEq(
            ownerLpTokens,
            initialToken1Amount,
            "LP token balance mismatch"
        );

        //Simulate unbalancing the pool by transferring tokens directly to the contract
        token1.transfer(address(dex), 5_000 ether);
        token2.transfer(address(dex), 1_000 ether);

        //Verify that reserves in the pool contract are now out of sync with tracked reserves
        uint256 actualToken1Balance = token1.balanceOf(address(dex));
        uint256 actualToken2Balance = token2.balanceOf(address(dex));
        assertEq(
            actualToken1Balance,
            initialToken1Amount + 5_000 ether,
            "Actual token1 balance mismatch after unbalanced transfer"
        );
        assertEq(
            actualToken2Balance,
            initialToken2Amount + 1_000 ether,
            "Actual token1 balance mismatch after unbalanced transfer"
        );

        //Attempts to remove liquidity with the original ratios (1:2) shoud now fail
        vm.startPrank(USER);
        uint256 lpTokensToBurn = ownerLpTokens / 2; //remove half liquidity
        vm.expectRevert(); //Pool empty (Dex__InsufficientLPBalance)
        dex.removeLiquidity(lpTokensToBurn);
        vm.stopPrank();

        //verify the state remains unchanged
        (uint256 updatedToken1Reserve, uint256 updatedToken2Reserve) = dex
            .getReserves();
        uint256 updateOwnerLpToken = dex.lpTokens(address(this));

        // Reserves and LP tokens should remain as they were before the failed removal
        assertEq(
            updatedToken1Reserve,
            token1Reserve,
            "Token1 reserve mismatch after failed removal"
        );
        assertEq(
            updatedToken2Reserve,
            token2Reserve,
            "Token2 reserve mismatch after failed removal"
        );
    }

    /// @notice Ensure that the removeLiquidity function correctly handles the removal of a very small (minimal) amount of LP tokens while maintaining precision in calculations.
    /// @dev Remove Liquidity with Minimal LP Tokens
    function test_RemoveLiquidityWithMinimalLPTokens() public {
        // Step 1: Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether;
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Verify initial reserves and total liquidity
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        uint256 totalLiquidity = dex.totalLiquidity();
        assertEq(
            totalLiquidity,
            initialToken1Amount,
            "Total liquidity mismatch"
        );
        assertEq(token1Reserve, initialToken1Amount, "Token1 reserve mismatch");
        assertEq(token2Reserve, initialToken2Amount, "Token2 reserve mismatch");

        // Record initial token balances of the owner
        uint256 initialOwnerToken1Balance = token1.balanceOf(address(this));
        uint256 initialOwnerToken2Balance = token2.balanceOf(address(this));

        // Step 2: Remove minimal LP tokens
        uint256 minimalLpTokensToBurn = 1; // Burn just 1 wei of LP tokens
        uint256 initialOwnerLpTokens = dex.lpTokens(address(this)); // Owner's LP tokens before removal
        assertGt(
            initialOwnerLpTokens,
            minimalLpTokensToBurn,
            "Insufficient LP tokens for removal"
        );

        // Calculate the expected token amounts to withdraw
        uint256 expectedToken1Amount = (minimalLpTokensToBurn * token1Reserve) /
            totalLiquidity;
        uint256 expectedToken2Amount = (minimalLpTokensToBurn * token2Reserve) /
            totalLiquidity;

        // Remove liquidity
        dex.removeLiquidity(minimalLpTokensToBurn);

        // Step 3: Verify the updated reserves
        (uint256 updatedToken1Reserve, uint256 updatedToken2Reserve) = dex
            .getReserves();
        assertEq(
            updatedToken1Reserve,
            token1Reserve - expectedToken1Amount,
            "Token1 reserve mismatch after minimal removal"
        );
        assertEq(
            updatedToken2Reserve,
            token2Reserve - expectedToken2Amount,
            "Token2 reserve mismatch after minimal removal"
        );

        // Step 4: Verify total liquidity is reduced by the burned LP tokens
        uint256 updatedTotalLiquidity = dex.totalLiquidity();
        assertEq(
            updatedTotalLiquidity,
            totalLiquidity - minimalLpTokensToBurn,
            "Total liquidity mismatch after minimal removal"
        );

        // Step 5: Verify owner's LP token balance is reduced
        uint256 updatedOwnerLpTokens = dex.lpTokens(address(this));
        assertEq(
            updatedOwnerLpTokens,
            initialOwnerLpTokens - minimalLpTokensToBurn,
            "LP token balance mismatch after minimal removal"
        );

        // Step 6: Verify token balances for the owner
        uint256 finalOwnerToken1Balance = token1.balanceOf(address(this));
        uint256 finalOwnerToken2Balance = token2.balanceOf(address(this));
        assertEq(
            finalOwnerToken1Balance,
            expectedToken1Amount + initialOwnerToken1Balance,
            "Owner's token1 balance mismatch after minimal removal"
        );
        assertEq(
            finalOwnerToken2Balance,
            expectedToken2Amount + initialOwnerToken2Balance,
            "Owner's token2 balance mismatch after minimal removal"
        );
    }

    ///@notice Remove Liquidity with No Tokens in Pool
    ///@dev Remove Liquidity with No Tokens in Pool (Should Revert)
    function test_RemoveLiquidityWithNoTokensInPool() public {
        //Attempts to remove liquidity without adding any tokens to the pool
        uint256 lpTokensToBurn = 1_000 ether; //Burn 1 LP tokens

        //Expect the transaction to revert becasue the pool has no tokens
        vm.expectRevert(); //Pool empty (Dex__InsufficientLPBalance)
        dex.removeLiquidity(lpTokensToBurn);

        //Verify that the total liquidity is still 0
        uint256 totalLiquidity = dex.totalLiquidity();
        assertEq(totalLiquidity, 0, "Total liquidity should remain zero");

        //Verify that the pool reserves are still 0
        (uint256 token1Reserve, uint256 token2Reserve) = dex.getReserves();
        assertEq(token1Reserve, 0, "Token1 reserve should remain zero");
        assertEq(token2Reserve, 0, "Token2 reserve should remain zero");
    }

    ///@notice Ensure Pool Integrity After Removing Liquidity
    ///@dev Ensure Pool Integrity After Removing Liquidity
    function test_EnsurePoolIntegrityAfterRemovingLiquidity() public {
        // Step 1: Add initial liquidity
        uint256 initialToken1Amount = 10_000 ether;
        uint256 initialToken2Amount = 20_000 ether; // 1:2 ratio
        dex.addLiquidity(initialToken1Amount, initialToken2Amount);

        // Step 2: Verify the initial pool state
        (uint256 token1ReserveBefore, uint256 token2ReserveBefore) = dex
            .getReserves();
        uint256 totalLiquidityBefore = dex.totalLiquidity();
        assertEq(
            token1ReserveBefore,
            initialToken1Amount,
            "Initial token1 reserve mismatch"
        );
        assertEq(
            token2ReserveBefore,
            initialToken2Amount,
            "Initial token2 reserve mismatch"
        );
        assertEq(
            totalLiquidityBefore,
            initialToken1Amount,
            "Initial total liquidity mismatch"
        );

        // Step 3: Remove some liquidity
        uint256 lpTokensToBurn = 5_000 ether; // Half of the LP tokens
        dex.removeLiquidity(lpTokensToBurn);

        // Step 4: Verify the updated pool state
        (uint256 token1ReserveAfter, uint256 token2ReserveAfter) = dex
            .getReserves();
        uint256 totalLiquidityAfter = dex.totalLiquidity();

        // Ensure pool reserves are updated proportionally to the liquidity removed
        uint256 expectedToken1Reserve = token1ReserveBefore -
            ((lpTokensToBurn * token1ReserveBefore) / totalLiquidityBefore);
        uint256 expectedToken2Reserve = token2ReserveBefore -
            ((lpTokensToBurn * token2ReserveBefore) / totalLiquidityBefore);
        uint256 expectedTotalLiquidity = totalLiquidityBefore - lpTokensToBurn;

        assertEq(
            token1ReserveAfter,
            expectedToken1Reserve,
            "Token1 reserve mismatch after removing liquidity"
        );
        assertEq(
            token2ReserveAfter,
            expectedToken2Reserve,
            "Token2 reserve mismatch after removing liquidity"
        );
        assertEq(
            totalLiquidityAfter,
            expectedTotalLiquidity,
            "Total liquidity mismatch after removing liquidity"
        );

        // Step 5: Check pool ratio remains consistent
        uint256 ratioBefore = (token1ReserveBefore * 1e18) /
            token2ReserveBefore; // token1/token2 ratio before
        uint256 ratioAfter = (token1ReserveAfter * 1e18) / token2ReserveAfter; // token1/token2 ratio after
        assertEq(
            ratioBefore,
            ratioAfter,
            "Token ratio mismatch after removing liquidity"
        );

        // Step 6: Ensure removing liquidity does not disrupt pool balance
        uint256 lpBalance = dex.lpTokens(address(this));
        assertGt(
            lpBalance,
            0,
            "LP token balance should remain after partial removal"
        );
    }

    function Add_initialLiquidity(
        uint256 initialToken1Anount,
        uint256 initialToken2Amount
    ) internal {
        dex.addLiquidity(initialToken1Anount, initialToken2Amount);
    }
}
