const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploy BondingCurveLib first
  const BondingCurveLib = await ethers.getContractFactory("BondingCurveLib");
  const bondingCurveLib = await BondingCurveLib.deploy();
  await bondingCurveLib.deployed();
  console.log("BondingCurveLib deployed to:", bondingCurveLib.address);

  // Deploy MySocialToken with UUPS proxy
  const MySocialToken = await ethers.getContractFactory("MySocialToken", {
    libraries: {
      BondingCurveLib: bondingCurveLib.address,
    },
  });

  const token = await upgrades.deployProxy(MySocialToken, 
    ["MySocial", "MYSO", await ethers.provider.getSigner().getAddress()],
    { initializer: 'initialize' }
  );
  await token.deployed();
  console.log("MySocial Token proxy deployed to:", token.address);

  // Deploy UsernameRegistry
  const UsernameRegistry = await ethers.getContractFactory("UsernameRegistry");
  const usernameRegistry = await UsernameRegistry.deploy();
  await usernameRegistry.deployed();
  console.log("UsernameRegistry deployed to:", usernameRegistry.address);

  // Deploy Presale contract
  const MySocialTokenPresale = await ethers.getContractFactory("MySocialTokenPresale");
  const presale = await MySocialTokenPresale.deploy(
    token.address,
    "0x8A04d904055528a69f3E4594DDA308A31aeb8457", // USDC address on Base testnet
    ethers.utils.parseEther("100000000"), // totalPresaleTokens
    ethers.utils.parseEther("10000000"),   // maxClaimPerWallet
    new Date('2025-01-16T18:00:00Z').getTime() / 1000, // presaleStartTime (Jan 16, 2025 12:00 PM Central)
    Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // presaleEndTime (7 days)
    ethers.utils.parseEther("0.0001"),   // basePrice
    ethers.utils.parseEther("0.00001")   // growthRate
  );
  await presale.deployed();
  console.log("Presale deployed to:", presale.address);

  // Set presale contract in token
  await token.setPresaleContract(presale.address);
  console.log("Presale contract set in token");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});