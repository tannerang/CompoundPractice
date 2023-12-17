// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { CToken } from  "../../src/CToken.sol";
import { Test } from "forge-std/Test.sol";
import "../../script/MyScript.s.sol";

contract FlashLoanSetUp is Test {
    address public adminAddr = makeAddr("admin");
    address USDCAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address UNIAddr = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    Comp public comp;
    WhitePaperInterestRateModel public interestRateModel;
    SimplePriceOracle public simplePriceOracle;
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comptroller public unitrollerProxy;
    CErc20Delegate public CErc20Delegate_;
    Erc20 public USDC;
    Erc20 public UNI;
    CErc20Delegator public cUSDC;
    CErc20Delegator public cUNI;

    function setUp() public virtual {
        
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_465_000);
        assertEq(block.number, 17_465_000);

        vm.startPrank(adminAddr);
        comp = new Comp(adminAddr);
        interestRateModel = new WhitePaperInterestRateModel(0, 0);
        simplePriceOracle = new SimplePriceOracle();
        comptroller = new Comptroller(address(comp));
        unitroller = new Unitroller();
        unitrollerProxy = Comptroller(address(unitroller));
        CErc20Delegate_ = new CErc20Delegate();
        USDC = Erc20(USDCAddr);
        UNI = Erc20(UNIAddr);

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(simplePriceOracle);

        cUSDC = new CErc20Delegator(
            USDCAddr, //The address of the underlying asset
            ComptrollerInterface(address(unitroller)), //The address of the Comptroller
            WhitePaperInterestRateModel(address(interestRateModel)), //The address of the interest rate model
            1e18, //initialExchangeRateMantissa_
            "Compound USDC", //name_
            "cUSDC", //symbol_
            18, //decimals_
            payable(adminAddr), //admin_
            address(CErc20Delegate_), //implementation_
            "" //becomeImplementationData
        );

        cUNI = new CErc20Delegator(
            UNIAddr, //The address of the underlying asset
            ComptrollerInterface(address(unitroller)), //The address of the Comptroller
            WhitePaperInterestRateModel(address(interestRateModel)), //The address of the interest rate model
            1e18, //initialExchangeRateMantissa_
            "Compound UNI", //name_
            "cUNI", //symbol_
            18, //decimals_
            payable(adminAddr), //admin_
            address(CErc20Delegate_), //implementation_
            "" //becomeImplementationData
        );

        vm.stopPrank();
    }
}