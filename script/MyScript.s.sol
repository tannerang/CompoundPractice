// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { CErc20Delegator } from "../src/CErc20Delegator.sol";
import { CErc20Delegate } from "../src/CErc20Delegate.sol";
import { Comptroller } from "../src/Comptroller.sol";
import { Unitroller } from "../src/Unitroller.sol";
import { SimplePriceOracle } from "../src/SimplePriceOracle.sol";
import { WhitePaperInterestRateModel } from "../src/WhitePaperInterestRateModel.sol";
import { Comp } from "../src/Governance/Comp.sol";
import "../src/CTokenInterfaces.sol";


contract MyScript is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Comp comp = new Comp(address(0x3B8569caF1D098718941B86001FeE0f3b668b629));
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(0, 0);
        SimplePriceOracle simplePriceOracle = new SimplePriceOracle();
        
        Comptroller comptroller = new Comptroller(address(comp));
        comptroller._setPriceOracle(simplePriceOracle);

        Unitroller unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);

        CErc20Delegate CErc20Delegate_ = new CErc20Delegate();
        CErc20Delegator CErc20Delegator_ = new CErc20Delegator(
            address(0x7169D38820dfd117C3FA1f22a697dBA58d90BA06), //underlying_
            ComptrollerInterface(address(unitroller)), 
            InterestRateModel(address(interestRateModel)),
            1e18, //initialExchangeRateMantissa_
            "Compound USDT Token", //name_
            "cUSDT", //symbol_
            18, //decimals_
            payable(address(0x3B8569caF1D098718941B86001FeE0f3b668b629)), //admin_
            address(CErc20Delegate_), //implementation_
            "" //becomeImplementationData
        );


        vm.stopBroadcast();
    }
}