require("@nomiclabs/hardhat-ethers");
require("@tenderly/hardhat-tenderly");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();
require("@nomiclabs/hardhat-truffle5");

const { utils } = require("ethers");

const PRIVATE_KEY_1 = process.env.PRIVATE_KEY_1;
const PRIVATE_KEY_2 = process.env.PRIVATE_KEY_2;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "localhost",
  networks: {
    hardhat: {},
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [`${PRIVATE_KEY_1}` , `${PRIVATE_KEY_2}`],
    },
    localhost: {
      url: "http://localhost:8545",
      // accounts: [`${PRIVATE_KEY_GANACHE_1}` , `${PRIVATE_KEY_GANACHE_2}`],
      timeout: 150000,
      // gasPrice: parseInt(utils.parseUnits("132", "gwei")),
    
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [`${PRIVATE_KEY_1}`],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.0",
      },
    ],
    optimizer: {
      enabled: false,
      runs: 200,
    },
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
  mocha: {
    timeout: 50000
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT,
    username: process.env.TENDERLY_USERNAME,
  },
};
