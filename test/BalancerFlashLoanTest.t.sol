// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { FlashLoanSetUp } from "./SetUp/FlashLoanSetUp.sol";
import { CToken } from  "../src/CToken.sol";
import { FlashLoanRecipient } from "../src/BalancerFlashLoan.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalancerFlashLoanTest is FlashLoanSetUp {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    
    FlashLoanRecipient public balancerFlashLoan;

    function setUp() public override {
        super.setUp();

        // Add CToken into the market 
        vm.startPrank(adminAddr);
        unitrollerProxy._supportMarket(CToken(address(cUSDC)));
        unitrollerProxy._supportMarket(CToken(address(cUNI)));
        
        // Check if CToken had added into the market 
        CToken[] memory allMarkets = unitrollerProxy.getAllMarkets();
        assertEq(address(cUSDC), address(allMarkets[0]));
        assertEq(address(cUNI), address(allMarkets[1]));

        // Initialize AaveFlashLoan
        balancerFlashLoan = new FlashLoanRecipient();
        //uint256 initialBalance = 10 * 10 ** 6;
        //deal(address(USDC), address(aaveFlashLoan), initialBalance);
        vm.stopPrank();
    }

    function testBalancerFlashLoanLiquidation() public {
        deal(UNIAddr, user1, 1000 * (10 ** UNI.decimals()));
        deal(USDCAddr, user2, 2500 * (10 ** USDC.decimals()));
        
        // 0. Admin setting
        vm.startPrank(adminAddr);
        simplePriceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1 * 10 ** (36 - USDC.decimals()));
        simplePriceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5 * 10 ** (36 - UNI.decimals()));
        unitrollerProxy._setLiquidationIncentive(1.08 * 1e18);
        unitrollerProxy._setCloseFactor(0.5 * 1e18);
        unitrollerProxy._setCollateralFactor(CToken(address(cUNI)), 0.5e18);
        vm.stopPrank();

        // 1. User2 approve and mint CToken (cUSDC)
        vm.startPrank(user2);
        USDC.approve(address(cUSDC), type(uint256).max);
        cUSDC.mint(2500 * 10 ** USDC.decimals());
        console2.log("user2's cUSDC after mint:", cUSDC.balanceOf(user2));
        console2.log("USDC balance of user2 after mint:", USDC.balanceOf(user2));
        vm.stopPrank();

        // 2. User1 approve and mint CToken (cUNI)
        vm.startPrank(user1);
        UNI.approve(address(cUNI), type(uint256).max);
        cUNI.mint(1000 * (10 ** UNI.decimals()));
        console2.log("user1's cUNI after mint:", cUNI.balanceOf(user1));
        console2.log("UNI balance of user1 after mint:", UNI.balanceOf(user1));

        // 3. Use Comptroller to enter the market
        address[] memory cToken = new address[](1);
        cToken[0] = (address(cUNI));
        unitrollerProxy.enterMarkets(cToken);

        // 4. Borrow, then check the underlying balance for this contract's address
        console2.log("USDC balance of user1 before borrow:", USDC.balanceOf(user1));
        cUSDC.borrow(2500 * 10 ** USDC.decimals());
        console2.log("USDC balance of user1 after borrow:", USDC.balanceOf(user1));

        (uint err, uint liquidity, uint shortfall) = unitrollerProxy.getAccountLiquidity(user1); // check liquidity
        require(err == 0, "getAccountLiquidity() failed");
        console2.log("Borrower(User1) liquidity:", liquidity);
        console2.log("Borrower(User1) shortfall:", shortfall);
        vm.stopPrank();

        // 5. Change UNI price into $4 and check user1's account liquidity
        vm.startPrank(adminAddr);
        simplePriceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4 * 10 ** (36 - UNI.decimals()));
        vm.stopPrank();

        (uint err_, uint liquidity_, uint shortfall_) = unitrollerProxy.getAccountLiquidity(user1); // check liquidity
        require(err_ == 0, "getAccountLiquidity() failed");
        console2.log("==== After Changing Price To $4 ====");
        console2.log("Borrower(User1) liquidity:", liquidity_);
        console2.log("Borrower(User1) shortfall:", shortfall_);

        // 6. Calculate repay amount
        vm.startPrank(user2);
        uint closeFactorMantissa = unitrollerProxy.closeFactorMantissa();
        uint boorowBalance = cUSDC.borrowBalanceCurrent(user1);
        uint repayAmount = boorowBalance * closeFactorMantissa / 1e18;
        console2.log("USDC repay amount:", repayAmount);
        
        // 7. User2 excute liquidating(flashloan) and earn 64.26 USD, which $0.63 more than AAVE-V3 (63.63 USD)
        uint[] memory amounts = new uint[](1);
        amounts[0] = repayAmount;
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(USDCAddr);

        bytes memory userData = abi.encode(user1, user2, address(cUSDC), address(cUNI), repayAmount);
        balancerFlashLoan.makeFlashLoan(tokens, amounts, userData);
        console2.log("USDC balance of user2 after excute liquidating(flashloan):", USDC.balanceOf(user2));
        console2.log("User2 earned about", USDC.balanceOf(user2)/1e6, "US Dollar via BALANCER.");
        console2.log("BALANCER's profit is more than AAVE-V3. ($64.26 - $63.63 = $0.63)");
        assertGt(USDC.balanceOf(user2), 64 * 10 ** USDC.decimals());
        assertLt(USDC.balanceOf(user2), 65 * 10 ** USDC.decimals());
        vm.stopPrank();
    }
}