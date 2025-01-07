// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./BondingCurveLib.sol";

contract MySocialToken is ERC20, Ownable, ReentrancyGuard {
    using BondingCurveLib for uint256;

    uint256 public basePrice;
    uint256 public growthRate;
    uint256 public totalPresaleTokens;
    uint256 public totalPresaleSold;
    uint256 public maxClaimPerWallet;
    bool public presaleActive;
    
    address public presaleContract;
    uint256 private constant TOTAL_SUPPLY_CAP = 1_000_000_000 * 10**18; // 1 billion tokens

    mapping(address => uint256) public walletClaims;
    mapping(address => uint256) public purchaseAmounts;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, uint256 amount, uint256 refund);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _basePrice,
        uint256 _growthRate,
        uint256 _totalPresaleTokens,
        uint256 _maxClaimPerWallet
    ) ERC20(name, symbol) Ownable(msg.sender) {
        require(_basePrice > 0, "Invalid base price");
        require(_growthRate > 0, "Invalid growth rate");
        require(_totalPresaleTokens > 0, "Invalid total presale tokens");
        require(_maxClaimPerWallet > 0, "Invalid max claim per wallet");
        
        basePrice = _basePrice;
        growthRate = _growthRate;
        totalPresaleTokens = _totalPresaleTokens;
        maxClaimPerWallet = _maxClaimPerWallet;
        presaleActive = true;
    }

    // ==============================
    // Bonding Curve Price Calculation
    // ==============================

    function calculatePrice(uint256 amount) public view returns (uint256) {
        return BondingCurveLib.calculatePrice(basePrice, growthRate, TOTAL_SUPPLY_CAP, amount);
    }

    function getCurrentPresalePrice(uint256 amount) external view returns (uint256) {
        return calculatePrice(amount);
    }

    // ==============================
    // Core Token Functions
    // ==============================

    function getTotalSupplyCap() external pure returns (uint256) {
        return TOTAL_SUPPLY_CAP;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner() || msg.sender == presaleContract, "Unauthorized");
        require(totalSupply() + amount <= TOTAL_SUPPLY_CAP, "Exceeds supply cap");
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        require(msg.sender == owner() || msg.sender == presaleContract, "Unauthorized");
        _burn(from, amount);
    }

    // ==============================
    // Admin Functions
    // ==============================

    function setPresaleContract(address _presaleContract) external onlyOwner {
        presaleContract = _presaleContract;
    }

    function togglePresale() external onlyOwner {
        presaleActive = !presaleActive;
    }

    // ==============================
    // Safety Features
    // ==============================

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }
}