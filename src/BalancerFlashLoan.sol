// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { console2 } from "forge-std/Test.sol";
import { CToken } from  "../src/CToken.sol";
import { CErc20 } from  "../src/CErc20.sol";

import "balancer-v2-monorepo/pkg/interfaces/contracts/vault/IVault.sol";
import "balancer-v2-monorepo/pkg/interfaces/contracts/vault/IFlashLoanRecipient.sol";

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

contract FlashLoanRecipient is IFlashLoanRecipient {
    address constant USDCAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant VAULT_ADDRESS = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    IVault private vault;
    
    IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    CErc20 public cUSDC;
    CErc20 public cUNI;

    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external {
      vault = IVault(VAULT_ADDRESS);
      vault.flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == VAULT_ADDRESS);

        IERC20(tokens[0]).approve(VAULT_ADDRESS, type(uint).max);
        (address borrower, address caller, address cUSDCAddr, address cUNIAddr, uint repayAmount) = abi.decode(userData,(address, address, address, address, uint));
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

        USDC.transfer(caller, amountOut - (repayAmount)); // Balancer flashloan fee 0%
        console2.log("USDC REPAY TO VAULT:", USDC.balanceOf(address(this)));
        USDC.transfer(VAULT_ADDRESS, USDC.balanceOf(address(this))); 
    }
}