const { expect } = require("chai");

describe("Pye Env", function () {
    it("Deploy pye position", async function () {

        const [admin] = await ethers.getSigners();


        const SWMock = await ethers.getContractFactory("SwEthVaulMock");
        const swMock = await SWMock.deploy();
        console.log("SWMock deployed to:", swMock.target);

        const Adapter = await ethers.getContractFactory("PyeStakeWise");
        const adapter = await Adapter.deploy(swMock.target);
        console.log("SWMock deployed to:", adapter.target);


        const Pye = await ethers.getContractFactory("Pye");
        const pye = await Pye.deploy();
        console.log("Pye deployed to:", pye.target);

        const PyeFactory = await ethers.getContractFactory("PyeFactory");
        const pyeFactory = await PyeFactory.deploy();
        const beaconTx = await pyeFactory.createBeacon(adapter.target);

        const beacon = (await beaconTx.wait()).logs[2].args[0];
        console.log("beacon:", beacon);

        await pye.connect(admin).updateProvider(beacon,true);


        let stakeTx = await pye.connect(admin).stake(beacon, ethers.parseEther("0.001"), 180 ,ethers.encodeBytes32String(""),{value:ethers.parseEther("0.001")});
        stakeTx = await stakeTx.wait();
        // console.log("stakeTx:", stakeTx.logs.filter((log) => log.args));

    });
});