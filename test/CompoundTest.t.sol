// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { CompoundSetUp } from "./SetUp/CompoundSetUp.sol";
import { Comptroller } from "../src/Comptroller.sol";
import { ComptrollerV7Storage, ComptrollerV2Storage } from "../src/ComptrollerStorage.sol";
import { CToken } from  "../src/CToken.sol";

contract CompoundTest is CompoundSetUp {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address liquidator = makeAddr("liquidator");

    function setUp() public override {
        super.setUp();

        vm.startPrank(adminAddr);

        // Add CToken into the market 
        Comptroller(address(unitroller))._supportMarket(CToken(address(cATK)));
        Comptroller(address(unitroller))._supportMarket(CToken(address(cATKB)));
        
        // Check if CToken had added into the market 
        CToken[] memory allMarkets = Comptroller(address(unitroller)).getAllMarkets();  //Comptroller(address(unitroller)).markets(address(cATK));
        assertEq(address(cATK), address(allMarkets[0]));
        assertEq(address(cATKB), address(allMarkets[1]));

        vm.stopPrank();
    }

    function testMintAndRedeem() public {
        deal(address(ATK), user1, 100 * 10 ** ATK.decimals());

        // 1. Approve and mint CToken
        vm.startPrank(user1);
        ATK.approve(address(cATK), type(uint256).max);
        cATK.mint(100 * 10 ** ATK.decimals());
        console2.log("user1's cATK after mint:", cATK.balanceOf(user1));
        console2.log("ATK balance of user1 after mint:", ATK.balanceOf(user1));

        // 2. Redeem all CToken
        cATK.redeem(cATK.balanceOf(user1));
        console2.log("user1's cATK after redeem:", cATK.balanceOf(user1));
        console2.log("ATK balance of user1 after redeem:", ATK.balanceOf(user1));
        vm.stopPrank();
    }

    function testBorrowAndRepay() public {
        deal(address(ATKB), user1, 1 * 10 ** ATKB.decimals());
        deal(address(ATK), user2, 1000 * 10 ** ATK.decimals());
       
        // 0. Admin setting
        vm.startPrank(adminAddr);
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATK)), 1 * 10 ** cATK.decimals());
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATKB)), 100 * 10 ** cATKB.decimals());
        unitrollerProxy._setCollateralFactor(CToken(address(cATKB)), 5 * 10 ** (cATKB.decimals() - 1));
        vm.stopPrank();

        // 1. User2 approve and mint CToken (TokenA)
        vm.startPrank(user2);
        ATK.approve(address(cATK), type(uint256).max);
        cATK.mint(1000 * 10 ** ATK.decimals());
        console2.log("user2's cATK after mint:", cATK.balanceOf(user2));
        console2.log("ATK balance of user2 after mint:", ATK.balanceOf(user2));
        vm.stopPrank();

        // 1. User1 approve and mint CToken (TokenB)
        vm.startPrank(user1);
        ATKB.approve(address(cATKB), type(uint256).max);
        cATKB.mint(1 * 10 ** ATKB.decimals());
        console2.log("user1's cATKB before borrow:", cATKB.balanceOf(user1));
        console2.log("ATKB balance of user1 before borrow:", ATKB.balanceOf(user1));

        // 2. Use Comptroller to enter the market
        address[] memory cToken = new address[](1);
        cToken[0] = (address(cATKB));
        unitrollerProxy.enterMarkets(cToken);
        
        // 3. Borrow, then check the underlying balance for this contract's address
        cATK.borrow(50 * 10 ** ATK.decimals());
        console2.log("user1's cATKB after borrow:", cATKB.balanceOf(user1));
        console2.log("ATK balance of user1 after borrow:", ATK.balanceOf(user1));

        (uint err, uint liquidity, uint shortfall) = unitrollerProxy.getAccountLiquidity(user1);
        require(err == 0, "getAccountLiquidity() failed");
        console2.log("Account liquidity liquidity:", liquidity);
        console2.log("Account liquidity shortfall:", shortfall);
        vm.stopPrank();
    }

    function testLiquidateViaCollateralFactor() public {
        deal(address(ATKB), user1, 1 * 10 ** ATKB.decimals());
        deal(address(ATK), user2, 100 * 10 ** ATK.decimals());
        
        // 0. Admin setting
        vm.startPrank(adminAddr);
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATK)), 1 * 10 ** cATK.decimals());
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATKB)), 100 * 10 ** cATKB.decimals());
        unitrollerProxy._setCollateralFactor(CToken(address(cATKB)), 5 * 10 ** (cATKB.decimals() - 1));
        unitrollerProxy._setCloseFactor(0.5e18);
        vm.stopPrank();

        // 1. User2 approve and mint CToken (TokenA)
        vm.startPrank(user2);
        ATK.approve(address(cATK), type(uint256).max);
        cATK.mint(100 * 10 ** ATK.decimals());
        console2.log("user2's cATK after mint:", cATK.balanceOf(user2));
        console2.log("ATK balance of user2 after mint:", ATK.balanceOf(user2));
        vm.stopPrank();

        // 1. User1 approve and mint CToken (TokenB)
        vm.startPrank(user1);
        ATKB.approve(address(cATKB), type(uint256).max);
        cATKB.mint(1 * 10 ** ATKB.decimals());
        console2.log("user1's cATKB before borrow:", cATKB.balanceOf(user1));
        console2.log("ATKB balance of user1 before borrow:", ATKB.balanceOf(user1));

        // 2. Use Comptroller to enter the market
        address[] memory cToken = new address[](1);
        cToken[0] = (address(cATKB));
        unitrollerProxy.enterMarkets(cToken);
        
        // 3. Borrow, then check the underlying balance for this contract's address
        cATK.borrow(50 * 10 ** ATK.decimals());
        console2.log("user1's cATKB after borrow:", cATKB.balanceOf(user1));
        console2.log("ATK balance of user1 after borrow:", ATK.balanceOf(user1));
        vm.stopPrank();

        // 4. Admin Update Collateral Factor
        vm.startPrank(adminAddr);
        unitrollerProxy._setCollateralFactor(CToken(address(cATKB)), 4 * 10 ** (cATKB.decimals() - 1));
        (uint err, uint liquidity, uint shortfall) = unitrollerProxy.getAccountLiquidity(user1);
        require(err == 0, "getAccountLiquidity() failed");
        console2.log("Account liquidity liquidity:", liquidity);
        console2.log("Account liquidity shortfall:", shortfall);
        vm.stopPrank();
        
        // 5. User2 excute liquidating
        vm.startPrank(user2);
        uint closeFactorMantissa = unitrollerProxy.closeFactorMantissa();
        uint boorowBalance = cATK.borrowBalanceCurrent(user1);
        uint repayAmount = boorowBalance * closeFactorMantissa / 1e18;
        console2.log("user2's closeFactorMantissa:", closeFactorMantissa);
        console2.log("user2's boorowBalance:", boorowBalance);
        console2.log("user2's repayAmount:", repayAmount);

        deal(address(ATK), user2, 100 * 10 ** ATK.decimals());
        console2.log("user2's ATK before liquidate:", cATK.balanceOf(user2));
        uint success = cATK.liquidateBorrow(user1, repayAmount, cATK);
        require(success == 0,  "liquidateBorrow() failed");
        console2.log("user2's ATK after liquidate:", cATK.balanceOf(user2));
        
        (uint err_, uint liquidity_, uint shortfall_) = unitrollerProxy.getAccountLiquidity(user1);
        require(err_ == 0, "getAccountLiquidity() failed");
        console2.log("Account liquidity liquidity:", liquidity_);
        console2.log("Account liquidity shortfall:", shortfall_);
        vm.stopPrank();
    }

    function testLiquidateViaChangingTokenPrice() public {
        deal(address(ATKB), user1, 1 * 10 ** ATKB.decimals());
        deal(address(ATK), user2, 100 * 10 ** ATK.decimals());

        // 0. Admin setting
        vm.startPrank(adminAddr);
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATK)), 1 * 10 ** cATK.decimals());
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATKB)), 100 * 10 ** cATKB.decimals());
        unitrollerProxy._setCollateralFactor(CToken(address(cATKB)), 5 * 10 ** (cATKB.decimals() - 1));
        unitrollerProxy._setCloseFactor(0.5e18);
        vm.stopPrank();

        // 1. User2 approve and mint CToken (TokenA)
        vm.startPrank(user2);
        ATK.approve(address(cATK), type(uint256).max);
        cATK.mint(100 * 10 ** ATK.decimals());
        console2.log("user2's cATK after mint:", cATK.balanceOf(user2));
        console2.log("ATK balance of user2 after mint:", ATK.balanceOf(user2));
        vm.stopPrank();

        // 1. User1 approve and mint CToken (TokenB)
        vm.startPrank(user1);
        ATKB.approve(address(cATKB), type(uint256).max);
        cATKB.mint(1 * 10 ** ATKB.decimals());
        console2.log("user1's cATKB before borrow:", cATKB.balanceOf(user1));
        console2.log("ATKB balance of user1 before borrow:", ATKB.balanceOf(user1));

        // 2. Use Comptroller to enter the market
        address[] memory cToken = new address[](1);
        cToken[0] = (address(cATKB));
        unitrollerProxy.enterMarkets(cToken);
        
        // 3. Borrow, then check the underlying balance for this contract's address
        cATK.borrow(50 * 10 ** ATK.decimals());
        console2.log("user1's cATKB after borrow:", cATKB.balanceOf(user1));
        console2.log("ATK balance of user1 after borrow:", ATK.balanceOf(user1));
        vm.stopPrank();

        // 4. Admin Update Collateral Factor
        vm.startPrank(adminAddr);
        simplePriceOracle.setUnderlyingPrice(CToken(address(cATKB)), 50 * 10 ** cATKB.decimals());
        (uint err, uint liquidity, uint shortfall) = unitrollerProxy.getAccountLiquidity(user1);
        require(err == 0, "getAccountLiquidity() failed");
        console2.log("Account liquidity liquidity:", liquidity);
        console2.log("Account liquidity shortfall:", shortfall);
        vm.stopPrank();
        
        // 5. User2 excute liquidating
        vm.startPrank(user2);
        uint closeFactorMantissa = unitrollerProxy.closeFactorMantissa();
        uint boorowBalance = cATK.borrowBalanceCurrent(user1);
        uint repayAmount = boorowBalance * closeFactorMantissa / 1e18;
        console2.log("user2's closeFactorMantissa:", closeFactorMantissa);
        console2.log("user2's boorowBalance:", boorowBalance);
        console2.log("user2's repayAmount:", repayAmount);

        deal(address(ATK), user2, 100 * 10 ** ATK.decimals());
        console2.log("user2's ATK before liquidate:", cATK.balanceOf(user2));
        uint success = cATK.liquidateBorrow(user1, repayAmount, cATK);
        require(success == 0,  "liquidateBorrow() failed");
        console2.log("user2's ATK after liquidate:", cATK.balanceOf(user2));
        
        (uint err_, uint liquidity_, uint shortfall_) = unitrollerProxy.getAccountLiquidity(user1);
        require(err_ == 0, "getAccountLiquidity() failed");
        console2.log("Account liquidity liquidity:", liquidity_);
        console2.log("Account liquidity shortfall:", shortfall_);
        vm.stopPrank();
    }
}