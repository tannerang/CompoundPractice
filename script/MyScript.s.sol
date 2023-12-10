// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/Script.sol";
import { CErc20Delegator } from "../src/CErc20Delegator.sol";
import { CErc20Delegate } from "../src/CErc20Delegate.sol";
import { Comptroller } from "../src/Comptroller.sol";
import { Unitroller } from "../src/Unitroller.sol";
import { SimplePriceOracle } from "../src/SimplePriceOracle.sol";
import { WhitePaperInterestRateModel } from "../src/WhitePaperInterestRateModel.sol";
import { Comp } from "../src/Governance/Comp.sol";
import { Erc20 } from "../src/Erc20.sol";
import "../src/CTokenInterfaces.sol";

contract MyScript is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address adminAddr = 0x3B8569caF1D098718941B86001FeE0f3b668b629;

        Comp comp = new Comp(adminAddr);
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(0, 0);
        SimplePriceOracle simplePriceOracle = new SimplePriceOracle();
        Comptroller comptroller = new Comptroller(address(comp));
        Unitroller unitroller = new Unitroller();
        CErc20Delegate CErc20Delegate_ = new CErc20Delegate();
        Erc20 underlyingToken = new Erc20("Ang Token", "ATK");

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        comptroller._setPriceOracle(simplePriceOracle);

        CErc20Delegator CErc20Delegator_ = new CErc20Delegator(
            address(underlyingToken), //The address of the underlying asset
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

        vm.stopBroadcast();
    }
}