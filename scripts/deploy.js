const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  // const splintersFactory = await ethers.getContractFactory("Splinters");
  // const splintersContract = await splintersFactory.deploy();

  // await splintersContract.deployed();
  // console.log(`Cyber Spawns Splinters contract Deployed: ${splintersContract.address}`);
  
  // if (hre.network.name === "mainnet" || hre.network.name === "testnet") {
  //   await hre.run("verify:verify", {
  //     address: splintersContract.address,
  //     constructorArguments: [],
  //   });
  // } else {
  //   console.log("Contracts deployed to", hre.network.name, "network. Please verify them manually.");
  // }

  // const nanoDoseFactory = await ethers.getContractFactory("NanoDose");
  // const nanoDoseContract = await nanoDoseFactory.deploy();

  // await nanoDoseContract.deployed();
  // console.log(`Cyber Spawns Nano Dose contract Deployed: ${nanoDoseContract.address}`);


  // if (hre.network.name === "mainnet" || hre.network.name === "testnet") {
  //   await hre.run("verify:verify", {
  //     address: nanoDoseContract.address,
  //     constructorArguments: [],
  //   });
  // } else {
  //   console.log("Contracts deployed to", hre.network.name, "network. Please verify them manually.");
  // }


  const cyberspawns721Factory = await ethers.getContractFactory("CyberSpawns721");
  const cyberspawns721Contract = await cyberspawns721Factory.deploy();

  await cyberspawns721Contract.deployed();
  console.log(`Cyber Spawns 721 contract Deployed: ${cyberspawns721Contract.address}`);


  if (hre.network.name === "mainnet" || hre.network.name === "testnet") {
    await hre.run("verify:verify", {
      address: cyberspawns721Contract.address,
      constructorArguments: [],
    });
  } else {
    console.log("Contracts deployed to", hre.network.name, "network. Please verify them manually.");
  }
}
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
