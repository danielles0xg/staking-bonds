
const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  const SC = await ethers.getContractFactory("TestContractOfferer");
  const instance = await SC.deploy(
    "0x0000000000000068F116a894984e2DB1123eB395"
  );
  
  console.log("Box deployed to:", instance.address);

  await hre.run("verify:verify", {
    address:  instance.target,
    constructorArguments: ["0x0000000000000068F116a894984e2DB1123eB395"],
});
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
