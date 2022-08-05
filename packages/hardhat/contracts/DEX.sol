// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DEX
 * @author Shiv Bhonde
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */
    IERC20 token;
    uint256 public totalLiquidity;
    mapping(address => uint) public liquidity;
    /* ========== EVENTS ========== */

    event EthToTokenSwap(
        address sender,
        string message,
        uint256 inputAmount,
        uint256 outputAmount
    );

    event TokenToEthSwap(
        address sender,
        string message,
        uint256 ethOutput,
        uint256 tokenInput
    );

    event LiquidityProvided(
        address provider,
        uint256 liquidityMinted,
        uint256 ethDeposit,
        uint256 tokenDeposit
    );

    event LiquidityRemoved(
        address liquidityRemover,
        uint256 liquidityRemoved,
        uint256 eth_amount,
        uint256 token_amount
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "Dex already has liquidity");
        liquidity[msg.sender] = msg.value;
        totalLiquidity = msg.value;
        require(token.transferFrom(msg.sender, address(this), tokens));
        return totalLiquidity;
    }

    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public view returns (uint256 yOutput) {
        uint256 input_token_with_fees = xInput * 997;
        uint256 numerator = yReserves * input_token_with_fees;
        uint256 denominator = (xReserves * 1000) + (input_token_with_fees);
        yOutput = numerator / denominator;
        return yOutput;
    }

    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "Cannot swap 0 ETH");
        uint256 xReserves = address(this).balance - msg.value;
        uint256 yReserves = token.balanceOf(address(this));

        tokenOutput = price(msg.value, xReserves, yReserves);

        require(
            token.transfer(msg.sender, tokenOutput),
            "ethToToken(): reverted swap."
        );
        emit EthToTokenSwap(
            msg.sender,
            "Eth to Balloons",
            msg.value,
            tokenOutput
        );
        return tokenOutput;
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "Cannot swapt 0 token");
        uint256 xReserves = address(this).balance;
        uint256 yReserves = token.balanceOf(address(this));

        ethOutput = price(tokenInput, yReserves, xReserves);

        require(
            token.transferFrom(msg.sender, address(this), tokenInput),
            "tokenToEth(): reverted swap."
        );
        (bool sent, ) = msg.sender.call{value: ethOutput}("");
        require(sent, "tokenToEth: revert in transferring eth to you!");
        emit TokenToEthSwap(
            msg.sender,
            "Balloons to ETH",
            ethOutput,
            tokenInput
        );
        return ethOutput;
    }

    function deposit() public payable returns (uint256 tokensDeposited) {
        uint256 xReserves = address(this).balance - msg.value;
        uint256 yReserves = token.balanceOf(address(this));

        uint256 xInput = msg.value;
        uint256 yInput = ((xInput * yReserves) / xReserves) + 1;

        require(token.transferFrom(msg.sender, address(this), yInput));

        uint256 sharesMinted = (xInput * totalLiquidity) / xReserves;

        liquidity[msg.sender] = liquidity[msg.sender] + sharesMinted;
        totalLiquidity = totalLiquidity + sharesMinted;

        emit LiquidityProvided(msg.sender, sharesMinted, msg.value, yInput);

        return yInput;
    }

    function withdraw(uint256 amount)
        public
        returns (uint256 eth_amount, uint256 token_amount)
    {
        require(
            liquidity[msg.sender] >= amount,
            "withdraw: sender does not have enough liquidity to withdraw."
        );

        uint256 xReserves = address(this).balance;
        uint256 yReserves = token.balanceOf(address(this));

        eth_amount = (xReserves * amount) / totalLiquidity;
        token_amount = (yReserves * amount) / totalLiquidity;

        liquidity[msg.sender] = liquidity[msg.sender] - amount;
        totalLiquidity = totalLiquidity - amount;
        (bool sent, ) = payable(msg.sender).call{value: eth_amount}("");
        require(sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, token_amount));
        emit LiquidityRemoved(msg.sender, amount, eth_amount, token_amount);
        return (eth_amount, token_amount);
    }
}
