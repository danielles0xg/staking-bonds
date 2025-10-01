
const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat")
const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');

const SW_HOLESKY_VAULT = "0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4";
const SW_HOLESKY_RWRDS = "0xB580799Bf7d62721D1a523f0FDF2f5Ed7BA4e259";

const MAINNET_VAULT = "0x8A93A876912c9F03F88Bc9114847cf5b63c89f56";
const MAINNET_KEEPER = "0x6B5815467da09DaA7DC83Db21c9239d98Bb487b5";

const { getRewardsProof } = require("./HarvestProof.js");
const { Contract } = require("ethers");

async function deployUpgradableBeacon(implementation) {
    const PyeStakeWise = await ethers.getContractFactory("PyeStakeWise");
    const AdapterBeacon = await upgrades.deployBeacon("0x4b9dDc7ead73Baf8B7B18047D3dEEceF4258E89f", {constructorArgs:[SW_HOLESKY_VAULT, SW_HOLESKY_RWRDS]});
    await AdapterBeacon.waitForDeployment();
    console.log("Beacon deployed to:", await AdapterBeacon.getAddress());// 0xe214F34b9e9ACCeA8Fae447f3fc8753fFF2eC1fC
}
async function create_position() {
    const [admin] = await ethers.getSigners();

    // const SWMock = await ethers.getContractFactory("SwEthVaulMock");
    // const swMock = await SWMock.deploy();
    // console.log("SWMock deployed to:", swMock.target);

    // const Adapter = await ethers.getContractFactory("PyeStakeWise");
    // const adapter = await Adapter.deploy(SW_HOLESKY_VAULT, SW_HOLESKY_RWRDS);
    // console.log("Adapter deployed to:", adapter.target);

    // await hre.run("verify:verify", { 
    //     address: "0x4b9dDc7ead73Baf8B7B18047D3dEEceF4258E89f",
    //     constructorArguments: [SW_HOLESKY_VAULT,SW_HOLESKY_RWRDS]
    // });

    // const RegistryFactory = await ethers.getContractFactory("Registry");
    // const Registry = await RegistryFactory.deploy(admin.address);
    // console.log("Registry deployed to:", Registry.target);
    // // deploy beacon a register it
    // await Registry.updateProvider(
    //     "0x4b9dDc7ead73Baf8B7B18047D3dEEceF4258E89f",400
    // );

    // const SchedulesFactory = await ethers.getContractFactory("Schedules");
    // const Schedules = await SchedulesFactory.deploy();
    // console.log("Schedules deployed to:", Schedules.target);

    // const Pye = await ethers.getContractFactory("Pye");
    // const pye = await Pye.deploy(
    //     "0x2DB1713ECb5F665841abe9f84035f3897cfceDA2",
    //     "0x511bE2e7a2ad6246D5a5539884a52bAc02A5A6b0"
    // );
    // console.log("Pye deployed to:", pye.target);

    /**
     *  
     *  Registry deployed to:  0x2DB1713ECb5F665841abe9f84035f3897cfceDA2
        Schedules deployed to: 0x511bE2e7a2ad6246D5a5539884a52bAc02A5A6b0
        Pye deployed to: 0x762a204437f0648821e0460FCae62c072A0fA27d
     */
    // await hre.run("verify:verify", {
    //     address: "0x762a204437f0648821e0460FCae62c072A0fA27d",
    //     constructorArguments: [
    //         "0x2DB1713ECb5F665841abe9f84035f3897cfceDA2",
    //         "0x511bE2e7a2ad6246D5a5539884a52bAc02A5A6b0",
    //     ]
    // });

    // await hre.run("verify:verify", { 
    //     address:  "0x1E6204B385c9AD0b9Ba7850a17a739348964e499",
    // });

    // await hre.run("verify:verify", { 
    //     contract:"openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy",
    //     address: "0xC73fa34aE2B6675adf28f54fC39bB026Cb0bb5c5",
    //     constructorArguments: [
    //         "0x52B60B8055D942FEEE24Cb407aaD701556eBE553",
    //         "0x608060405261000c61000e565b005b61001e610019610020565b6100b6565b565b60007f00000000000000000000000052b60b8055d942feee24cb407aad701556ebe55373ffffffffffffffffffffffffffffffffffffffff16635c60da1b6040518163ffffffff1660e01b8152600401602060405180830381865afa15801561008d573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906100b191906100da565b905090565b3660008037600080366000845af43d6000803e8080156100d5573d6000f35b3d6000fd5b6000602082840312156100ec57600080fd5b815173ffffffffffffffffffffffffffffffffffffffff8116811461011057600080fd5b939250505056fea26469706673582212206909d142e546ccc3d3e761b2821f896a54e3b6a16dd2132609553a059c71564d64736f6c63430008160033"
    //     ]
    // });
    // const adapter = "0xf61A19cdb1Eb30A338225394fB630178ff2bbCEb";
    // const pye ="0xC1699026C8188cE3B63fe33E51C818ac799fC07c"

    // const PyeFactory = await ethers.getContractFactory("PyeFactory");
    // const pyeFactory = await PyeFactory.deploy();

    // const PyeFactory = await ethers.getContractAt("PyeFactory", "0x74eB9Fe376D813c4F6305f4CF960b79AEcEdF0c3");
    // const adapter = "0x31b523f7214A29D48bd52a9c8783D377685F9d30";
    // const beaconTx = await PyeFactory.createBeacon(adapter);
    // const beaconAwaiter = await beaconTx.wait();
    // const beacon = beaconAwaiter.logs[2].args[0];
    // console.log("beacon:", beacon);

    // await hre.run("verify:verify", { 
    //     contract:"src/tokens/UpgradeableBeacon.sol:UpgradeableBeacon",
    //     address: "0x52B60B8055D942FEEE24Cb407aaD701556eBE553",
    //     constructorArguments: ["0x31b523f7214A29D48bd52a9c8783D377685F9d30",""]
    // });

    //address implementation_, address initialOwner
    // const beacon= "0x52B60B8055D942FEEE24Cb407aaD701556eBE553"
    // // const tx_updateProvider = await pye.connect(admin).updateProvider(beacon,true);
    // // const receipt_updateProvider = await tx_updateProvider.wait();
    // // console.log("receipt_updateProvider",receipt_updateProvider)
    // console.log(await pye.wlBeacons(beacon));

    // let stakeTx = await pye.stake(
    //     beacon, ethers.parseEther("0.001"), 1 ,[],
    //     {
    //         value:ethers.parseEther("0.001"),
    //         gasPrice: 4792576879,

    //     }
    // );
    // stakeTx = await stakeTx.wait();
    // console.log("stakeTx:", stakeTx);
}

async function getProof(vault,keeper) {
    let proof = await getRewardsProof(ethers.getAddress(vault), ethers.getAddress(keeper));
    return proof;
}

async function initPosition(pyeAddress){
    const [admin] = await ethers.getSigners();
    const Pye = await ethers.getContractAt("Pye", pyeAddress);
    const positionAddress = await Pye.positionAddress(4);
    console.log("positionAddress:", positionAddress);

    const PyeStakeWise = await ethers.getContractAt("PyeStakeWise", positionAddress);
    const needsHarvest = await PyeStakeWise.isHarvestRequired();
    console.log("needsHarvest",needsHarvest)
    const proof = await getProof(SW_HOLESKY_VAULT, SW_HOLESKY_RWRDS)
    const amount = ethers.parseEther("0.001");

    console.log("proof:", proof);

    const receive = await Pye.connect(admin).createPosition(
        "0x7fcef3669d35e097c0c90e21050d90d783ce1af6",
        amount,3000,1726943464,proof,
        {value: amount},
    );
    console.log(receive)
}


async function main() {
    await initPosition("0x5C5f74a93EC9C62fF71F659f4FD0a4464E1C1eAd");
    // await proof();
    // await create_position();
    // await intialPosition();
}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});


/**
 * CAST CALLS
 * check unstake index in queue
 *  cast call 0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4 "getExitQueueIndex(uint256)(int256)" 87009298041973507679 --chain holesky --rpc-url $HOLESKY_URL
 * 
 * seaport 
 *     function createConduit(
        bytes32 conduitKey,
        address initialOwner
    ) external override returns (address conduit) {

 * cast send 0x00000000F9490004C11Cef243f5400493c00Ad63 "createConduit((bytes32,address))" "(0x771ecE2e88227eFD0a8C2FD991c7b15Ae9E8b977000000000000000000000000,0x771ecE2e88227eFD0a8C2FD991c7b15Ae9E8b977)" --chain holesky --rpc-url $HOLESKY_URL --private-key 0x4594174f9555b55c2baf15f1747539a748a1ca8d1e3d51836f31b59de67a677d
 * 
 */