// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "./Interfaces/IERC20.sol";
import "./Interfaces/IUniswapV3Pool.sol";
import "./Interfaces/IWETH.sol"; 

// Assumes flashloan miner has capital in ETH and only ETH
// Currently no fee
contract FlashTots {
    IWETH private immutable WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);    // token1
    IERC20 private immutable USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);     // token0
    IUniswapV3Pool public immutable pool = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    mapping(address => uint256) debt;

    function flashloanWETH(address to) public payable {
        require(msg.sender == block.coinbase);
        WETH.deposit{value : msg.value}();
        WETH.transfer(to, msg.value);
        debt[to] = msg.value;
    }

    function flashloanUSDC(address to, uint256 amount, uint160 min) external payable {
        require(msg.sender == block.coinbase);
        WETH.deposit{value : msg.value}();
        WETH.transfer(address(pool), msg.value);
        (int256 returned, ) = pool.swap(address(this), false, CastU256I256.i256(amount), min, bytes('0'));
        USDC.transfer(to, uint256(returned));
        debt[to] = msg.value;
    }

    function repayUSDC(address from, uint160 min, uint256 tip) external {
        uint256 userDebt = debt[from];
        USDC.transferFrom(msg.sender, address(this), userDebt);
        (,int256 returned) = pool.swap(address(this), true, CastU256I256.i256(userDebt), min, bytes('0'));
        require(uint256(returned) >= userDebt);
        WETH.withdraw(uint256(returned));
        block.coinbase.transfer(uint256(returned) + tip);
        debt[from] = 0;
    }

    function repayWETH(address from, uint256 tip) external {
        uint256 userDebt = debt[from];
        WETH.withdraw(userDebt);
        block.coinbase.transfer(userDebt + tip);
        debt[from] = 0;
    }
}