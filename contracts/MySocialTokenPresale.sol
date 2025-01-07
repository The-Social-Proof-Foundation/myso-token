// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MySocialToken.sol";
import "./BondingCurveLib.sol";
contract MySocialTokenPresale is ReentrancyGuard, Ownable {
    using BondingCurveLib for uint256;

    MySocialToken public token;
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public maxClaimPerWallet;
    mapping(address => uint256) public walletClaims;
    mapping(address => uint256) public purchaseAmounts;

    uint256 public totalPresaleTokens;
    uint256 public totalPresaleSold;
    bool public presaleActive = true;

    uint256 public basePrice;
    uint256 public growthRate;

    IERC20 public usdcToken;
    bool public acceptUsdc;
    uint256 public usdcDecimals;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, uint256 amount, uint256 refund);

    constructor(
        address tokenAddress,
        address _usdcAddress,
        uint256 _totalPresaleTokens,
        uint256 _maxClaimPerWallet,
        uint256 _presaleStartTime,
        uint256 _presaleEndTime,
        uint256 _basePrice,
        uint256 _growthRate
    ) Ownable(msg.sender) {
        token = MySocialToken(payable(tokenAddress));
        require(token.owner() == msg.sender, "Owner must be the same as token owner");
        require(_presaleStartTime < _presaleEndTime, "Invalid time range");
        require(_presaleEndTime > block.timestamp, "End time must be in future");
        
        totalPresaleTokens = _totalPresaleTokens;
        maxClaimPerWallet = _maxClaimPerWallet;
        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleEndTime;
        basePrice = _basePrice;
        growthRate = _growthRate;

        usdcToken = IERC20(_usdcAddress);
        usdcDecimals = 6;
        acceptUsdc = true;
    }

    // ==============================
    // Buy / Sell Presale Tokens Functions
    // ==============================

    function _calculatePresalePrice(uint256 amount) internal view returns (uint256) {
        return BondingCurveLib.calculatePrice(basePrice, growthRate, token.getTotalSupplyCap(), amount);
    }

    function getCurrentPresalePrice(uint256 amount) external view returns (uint256) {
        return _calculatePresalePrice(amount);
    }

    function buyPresaleTokensWithEth(uint256 amount) external payable nonReentrant {
        require(presaleActive, "Presale is not active");
        require(block.timestamp >= presaleStartTime, "Presale not started");
        require(block.timestamp <= presaleEndTime, "Presale ended");
        require(totalPresaleSold + amount <= totalPresaleTokens, "Exceeds presale supply");
        require(walletClaims[msg.sender] + amount <= maxClaimPerWallet, "Exceeds claim limit");

        uint256 cost = _calculatePresalePrice(amount);
        require(msg.value >= cost, "Insufficient ETH sent");

        walletClaims[msg.sender] += amount;
        totalPresaleSold += amount;
        purchaseAmounts[msg.sender] += cost;

        token.mint(msg.sender, amount);

        emit TokensPurchased(msg.sender, amount, cost);

        if (msg.value > cost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - cost}("");
            require(success, "ETH transfer failed");
        }
    }

    function buyPresaleTokensWithUsdc(uint256 amount) external nonReentrant {
        require(acceptUsdc, "USDC payments not accepted");
        require(presaleActive, "Presale is not active");
        require(block.timestamp >= presaleStartTime, "Presale not started");
        require(block.timestamp <= presaleEndTime, "Presale ended");
        require(totalPresaleSold + amount <= totalPresaleTokens, "Exceeds presale supply");
        require(walletClaims[msg.sender] + amount <= maxClaimPerWallet, "Exceeds claim limit");

        uint256 cost = _calculatePresalePrice(amount);
        uint256 usdcCost = (cost * (10 ** usdcDecimals)) / (10 ** 18);
        
        require(usdcToken.balanceOf(msg.sender) >= usdcCost, "Insufficient USDC balance");
        require(usdcToken.transferFrom(msg.sender, address(this), usdcCost), "USDC transfer failed");

        walletClaims[msg.sender] += amount;
        totalPresaleSold += amount;
        purchaseAmounts[msg.sender] += cost;

        token.mint(msg.sender, amount);

        emit TokensPurchased(msg.sender, amount, cost);
    }

    function sellPresaleTokens(uint256 amount) external nonReentrant {
        require(presaleActive, "Presale is not active");
        require(block.timestamp >= presaleStartTime, "Presale not started");
        require(block.timestamp <= presaleEndTime, "Presale ended");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient tokens to sell");

        uint256 refund = purchaseAmounts[msg.sender] * amount / walletClaims[msg.sender];
        require(refund > 0, "No refundable ETH available");

        walletClaims[msg.sender] -= amount;
        totalPresaleSold -= amount;
        purchaseAmounts[msg.sender] -= refund;

        token.burnFrom(msg.sender, amount);

        (bool success, ) = payable(msg.sender).call{value: refund}("");
        require(success, "ETH transfer failed");

        emit TokensSold(msg.sender, amount, refund);
    }

    function getPresaleDuration() external view returns (uint256 start, uint256 end) {
        return (presaleStartTime, presaleEndTime);
    }

    // ==============================
    // Admin Functions
    // ==============================

    function togglePresale() external onlyOwner {
        presaleActive = !presaleActive;
        acceptUsdc = presaleActive;
    }

    function withdrawFunds() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    function withdrawAmount(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = owner().call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function withdrawUsdc() external onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance > 0, "No USDC to withdraw");
        require(usdcToken.transfer(owner(), balance), "USDC transfer failed");
    }

    // ==============================
    // Safety Features
    // ==============================

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }
}