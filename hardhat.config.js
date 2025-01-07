require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();

module.exports = {
  solidity: {
    version: "0.8.23",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    baseTestnet: {
      url: process.env.BASE_TESTNET_RPC,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 84531
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};