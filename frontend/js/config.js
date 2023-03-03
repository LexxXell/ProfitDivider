import abi from './abi.js';
export default {
  wssProviderUrl: 'wss://ancient-thrumming-tree.bsc-testnet.discover.quiknode.pro/5dfad2e854856d15e94921a6b07aa95e80b35a73/',
  contractAddress: '0xe278C3eFB9751b7C0Ab2E6E44059E800550853A7',
  abi,
  chainParams: {
    chainId: '0x61',
    chainName: 'BNB Testnet',
    rpcUrls: ['https://data-seed-prebsc-1-s3.binance.org:8545'] /* ... */,
    nativeCurrency: {
      name: 'Testnet BNB',
      symbol: 'tBNB', // 2-6 characters long
      decimals: 18,
    },
  },
};
