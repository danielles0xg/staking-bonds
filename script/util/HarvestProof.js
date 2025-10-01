const ethers = require('ethers');
const RewardsContractAbi = require('./RewardsAbi.json');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');


dotenv.config();

const HOLESKY_URL = "https://holesky.infura.io/v3/0f16b26af1dc41ceb5ebf74a86e1d5b3";
const MAINNET_URL = "https://mainnet.infura.io/v3/0f16b26af1dc41ceb5ebf74a86e1d5b3";

async function getRewardsProof(ethVault,keeper ) {
    // console.log("ethVault:", ethVault);
    // console.log("kepper:", keeper);

    const provider = new ethers.JsonRpcProvider(HOLESKY_URL);
    const currentBlockNumber = await provider.getBlockNumber();
    // console.log("currentBlockNumber:", currentBlockNumber);

    // calculate last 12 hrs
    const fromNum = currentBlockNumber - 3600; // approx every 12 hrs
    const toNum = currentBlockNumber;
    // get rewards contract events
    const contract = new ethers.Contract(keeper, RewardsContractAbi.abi, provider);
    const events = await contract.queryFilter('RewardsUpdated(address,bytes32,uint256,uint64,uint64,string)', fromNum, toNum);
    // extract ipfs hash from the event

    // console.log("events:", ...events[0].args);
    const ipfsHash = events[0].args[events[0].args.length - 1];
    const data = await _getDataFromIPFS(ipfsHash);

    let proof = await data.vaults.filter(v => v.vault == ethVault)
    console.log("proof:",proof)
    proof = proof[0].proof;
    return proof;
}

async function _getDataFromIPFS(ipfsHash) {
    const ipfsGateway = 'https://ipfs.io/ipfs/';
    try {
        const response = await fetch(`${ipfsGateway}${ipfsHash}`);
        const data = await response.json();
        return await data;
    } catch (err) {
        console.log("Error: " + err.message);
    }
}

async function perform(){
    const args = process.argv.slice(2);
    if(args.length == 0) return;
    const MAINNET_VAULT = args[0]; //"0xB36Fc5e542cb4fC562a624912f55dA2758998113";
    const MAINNET_KEEPER = args[1]; // "0x6B5815467da09DaA7DC83Db21c9239d98Bb487b5";
    let proof = await getRewardsProof(
        ethers.getAddress(MAINNET_VAULT),
        ethers.getAddress(MAINNET_KEEPER)
    );

    // forge takes this console.log as input for fork test script
    const encoder = new ethers.AbiCoder();
    proof = encoder.encode(["bytes32[]"],[proof]);
    console.log(proof); 
}
perform().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

module.exports = {getRewardsProof};