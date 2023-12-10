// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import "../../script/MyScript.s.sol";

contract CompoundSetUp is Test {
    address public adminAddr = makeAddr("admin");

    Comp public comp;
    WhitePaperInterestRateModel public interestRateModel;
    SimplePriceOracle public simplePriceOracle;
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comptroller public unitrollerProxy;
    CErc20Delegate public CErc20Delegate_;
    Erc20 public ATK;
    Erc20 public ATKB;
    CErc20Delegator public cATK;
    CErc20Delegator public cATKB;

    function setUp() public virtual {

        vm.startPrank(adminAddr);

        comp = new Comp(adminAddr);
        interestRateModel = new WhitePaperInterestRateModel(0, 0);
        simplePriceOracle = new SimplePriceOracle();
        comptroller = new Comptroller(address(comp));
        unitroller = new Unitroller();
        unitrollerProxy = Comptroller(address(unitroller));
        CErc20Delegate_ = new CErc20Delegate();
        ATK = new Erc20("Ang Token", "ATK");
        ATKB = new Erc20("Ang Token B", "ATKB");

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(simplePriceOracle);

        cATK = new CErc20Delegator(
            address(ATK), //The address of the underlying asset
            ComptrollerInterface(address(unitroller)), //The address of the Comptroller
            WhitePaperInterestRateModel(address(interestRateModel)), //The address of the interest rate model
            1e18, //initialExchangeRateMantissa_
            "Compound Ang Token", //name_
            "cATK", //symbol_
            18, //decimals_
            payable(adminAddr), //admin_
            address(CErc20Delegate_), //implementation_
            "" //becomeImplementationData
        );

        cATKB = new CErc20Delegator(
            address(ATKB), //The address of the underlying asset
            ComptrollerInterface(address(unitroller)), //The address of the Comptroller
            WhitePaperInterestRateModel(address(interestRateModel)), //The address of the interest rate model
            1e18, //initialExchangeRateMantissa_
            "Compound Ang Token B", //name_
            "cATKB", //symbol_
            18, //decimals_
            payable(adminAddr), //admin_
            address(CErc20Delegate_), //implementation_
            "" //becomeImplementationData
        );

        vm.stopPrank();
    }
}