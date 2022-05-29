/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 * 
 * https://trufflesuite.com/docs/truffle/reference/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

 const HDWalletProvider = require('@truffle/hdwallet-provider');
 const fs = require('fs');
 const keyMainnet = fs.readFileSync(<PRIVATE_KEY_PATH>).toString().trim();
 const keyTestNet = fs.readFileSync(<PRIVATE_KEY_PATH>).toString().trim();
 const apiKey = fs.readFileSync(<BSC_API_KEY_PATH>).toString().trim();
 
 module.exports = {
   plugins: [
     'truffle-plugin-verify'
   ],
   api_keys: {

     bscscan: apiKey
   },
   /**
    * Networks define how you connect to your ethereum client and let you set the
    * defaults web3 uses to send transactions. If you don't specify one truffle
    * will spin up a development blockchain for you on port 9545 when you
    * run `develop` or `test`. You can ask a truffle command to use a specific
    * network from the command line, e.g
    *
    * $ truffle test --network <network-name>
    */
 
   networks: {
     // Useful for testing. The `development` name is special - truffle uses it by default
     // if it's defined here and no other network is specified at the command line.
     // You should run a client (like ganache-cli, geth or parity) in a separate terminal
     // tab if you use this network and you must also set the `host`, `port` and `network_id`
     // options below to some value.
     //
     development: {
       host: "127.0.0.1",     // Localhost (default: none)
       port: 8545,            // Standard BSC port (default: none)
       network_id: "*",       // Any network (default: none)
       gasPrice: 0x1,
       gas: 4710000
     },
     bscTestNet: {
       provider: () => new HDWalletProvider(keyTestNet, `https://data-seed-prebsc-1-s1.binance.org:8545`),
       network_id: 97,
       confirmations: 5,
       timeoutBlocks: 200,
       skipDryRun: true
     },
     bscMainNet: {
       provider: () => new HDWalletProvider(keyMainnet, `https://bsc-dataseed1.binance.org/`),
       network_id: 56,
       confirmations: 10,
       timeoutBlocks: 200,
       skipDryRun: true
     },
     
   },
 
   // Configure your compilers
   compilers: {
     solc: {
       version: "pragma",     // Fetch exact version from solc-bin (default: truffle's version)
       // docker: true,      // Use "0.5.1" you've installed locally with docker (default: false)
       settings: {           // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
       },
       //  evmVersion: "byzantium"
       }
     }
   },
 
   // Truffle DB is currently disabled by default; to enable it, change enabled:
   // false to enabled: true. The default storage location can also be
   // overridden by specifying the adapter settings, as shown in the commented code below.
   //
   // NOTE: It is not possible to migrate your contracts to truffle DB and you should
   // make a backup of your artifacts to a safe location before enabling this feature.
   //
   // After you backed up your artifacts you can utilize db by running migrate as follows:
   // $ truffle migrate --reset --compile-all
   //
   // db: {
     // enabled: false,
     // host: "127.0.0.1",
     // adapter: {
     //   name: "sqlite",
     //   settings: {
     //     directory: ".db"
     //   }
     // }
   // }
 };
 