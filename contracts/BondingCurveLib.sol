// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BondingCurveLib {
    function calculatePrice(uint256 basePrice, uint256 growthRate, uint256 supply, uint256 amount) public pure returns (uint256) {
        // Calculate the sum of prices for each token in the range
        uint256 totalCost = 0;
        for (uint256 i = 0; i < amount; i++) {
            uint256 currentSupply = supply + i;
            uint256 tokenPrice = basePrice + (growthRate * log2(currentSupply + 1));
            totalCost += tokenPrice;
        }
        return totalCost;
    }

    function log2(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 result = 0;
        while (x > 1) {
            x >>= 1;
            result++;
        }
        return result;
    }
}