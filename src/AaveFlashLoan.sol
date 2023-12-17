// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CErc20 } from "./CErc20.sol";
import { CToken } from  "../src/CToken.sol";
import { Comptroller } from "../src/Comptroller.sol";
import {
  IFlashLoanSimpleReceiver,
  IPoolAddressesProvider,
  IPool
} from "../lib/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

interface ISwapRouter  {
    struct ExactInputSingleParams {
          address tokenIn;
          address tokenOut;
          uint24 fee;
          address recipient;
          uint256 deadline;
          uint256 amountIn;
          uint256 amountOutMinimum;
          uint160 sqrtPriceLimitX96;
      }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract AaveFlashLoan is IFlashLoanSimpleReceiver {
  address constant USDCAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
  IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  IERC20 public UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  CErc20 public cUSDC;
  CErc20 public cUNI;

  function executeOperation(
      address asset,
      uint256 amount,
      uint256 premium,
      address initiator,
      bytes calldata params
    ) external returns (bool) {

      IERC20(asset).approve(address(POOL()), type(uint).max);
      (address borrower, address caller, address cUSDCAddr, address cUNIAddr, uint repayAmount) = abi.decode(params,(address, address, address, address, uint));
      cUSDC = CErc20(cUSDCAddr);
      cUNI = CErc20(cUNIAddr);
      USDC.approve(cUSDCAddr, 10000 * 10 ** 18);
      uint success = cUSDC.liquidateBorrow(borrower, repayAmount, CToken(cUNIAddr));
      require(success == 0, "compound: liquidateBorrow() failed");

      uint successRedeem = cUNI.redeem(cUNI.balanceOf(address(this)));
      require(successRedeem == 0, "compound: redeem() failed");

      UNI.approve(0xE592427A0AEce92De3Edee1F18E0157C05861564, type(uint).max);
      ISwapRouter.ExactInputSingleParams memory swapParams =
        ISwapRouter.ExactInputSingleParams({
          tokenIn: address(UNI),
          tokenOut: address(USDC),
          fee: 3000, // 0.3%
          recipient: address(this),
          deadline: block.timestamp+10,
          amountIn: UNI.balanceOf(address(this)),
          amountOutMinimum: 0,
          sqrtPriceLimitX96: 0
        });
      uint256 amountOut = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564).exactInputSingle(swapParams);
      USDC.transfer(caller, amountOut - (repayAmount * 10005 / 10000)); // aave-v3 fee 0.05%

      return true;
    }

  function execute(address borrower, address caller, address cUSDCAddr, address cUNIAddr, uint repayAmount) external {
    IPool(POOL()).flashLoanSimple(
      address(this),
      USDCAddr,
      repayAmount,
      abi.encode(borrower, caller, cUSDCAddr, cUNIAddr, repayAmount),
      0
    );
  }

  function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
    return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
  }

  function POOL() public view returns (IPool) {
    return IPool(ADDRESSES_PROVIDER().getPool());
  }
}
