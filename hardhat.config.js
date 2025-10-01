const dotenv = require("dotenv");
dotenv.config();

require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
require("@nomicfoundation/hardhat-verify");
require('@openzeppelin/hardhat-upgrades');
// require("hardhat-gas-reporter");
// require("hardhat-tracer");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
    },
    local: {
      chainId: 1337,
      url: "http://127.0.0.1:8545/",
      accounts: [`${process.env.PK}`]

    },
    mainnet: {
      url: `${process.env.MAINNET_URL}`,
      chainId: 1,
      accounts: [`${process.env.PK}`],
      blockNumber: 19997055,

    },
    holesky:{
      url: `${process.env.HOLESKY_URL}`,
      chainId: 17000,
      accounts: [`${process.env.PK}`],
      gasPrice: 4100000000,
      blockNumber: 1663670,
      blockGasLimit: 100000001000000000
    },
    sepolia:{
      url: `${process.env.SEPOLIA_URL}`,
      chainId: 11155111,
      accounts: [`${process.env.PK}`],
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 2000,
           
          }
        }
      },
      {
        version: "0.8.24",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 2000,
           
          }
        }
      },
      {
        version: "0.8.22",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 2000
          }
        }
      },
      {
        version: "0.8.14",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 2000
          }
        }
      },
    ]
  },
  etherscan: {
    apiKey: "YGJJZ2QH42R2W66DD3CJHTJA75D1RDTATD"
  },
  paths: {
    artifacts: "./out"
  },
  // gasReporter: {
  //   enabled: true,
  //   currency: 'USD',
  //   gasPrice: 21,
  //   coinmarketcap: process.env.COIN_MARKET_CAP_KEY,
  //   token: 'ETH',
  //   showMethodSig: true,
  //   gasPriceApi: `https://api.etherscan.io/api?module=stats&action=ethprice&apikey=4PKTG97IJD2JS3BSZQTJ3BX4YS5W3BMP4G`
  // }
};
/**
 *     gasReporter: {
        enabled: true,
        currency: 'USD',
        gasPrice: 21,
        coinmarketcap: process.env.COIN_MARKET_CAP_KEY,
        token: 'MATIC',
        showMethodSig: true,
        gasPriceApi: `https://api.polygonscan.com/api?module=stats&action=maticprice&apikey=U5HPG45VAZXXSJJTR32ABXVHPCIKYPE347`
    },
 */