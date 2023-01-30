import config from './config.js';

const buttonEthEnable = document.getElementById('button-eth-enable');
const labelEthAccount = document.getElementById('label-eth-account');
const inputPdAddress = document.getElementById('input-pd-address');

const buttonMyBalance = document.getElementById('button-contract-myBalance');
const labelMyBalance = document.getElementById('label-contract-myBalance');

const buttonContractOwner = document.getElementById('button-contract-owner');
const labelContractOwner = document.getElementById('label-contract-owner');

const inputContractBalanceOf = document.getElementById('input-contract-balanceOf');
const buttonContractBalanceOf = document.getElementById('button-contract-balanceOf');
const labelContractBalanceOf = document.getElementById('label-contract-balanceOf');

const buttonContractAccumulatedPfofit = document.getElementById('button-contract-accumulatedPfofit');
const labelContractAccumulatedPfofit = document.getElementById('label-contract-accumulatedPfofit');

const ethEnable = async () => {
  if (window.ethereum) {
    window.accounts = await window.ethereum.request({
      method: 'eth_requestAccounts',
    });
    window.web3 = new Web3(window.ethereum);
    window.web3_wss = new Web3('wss://ancient-thrumming-tree.bsc-testnet.discover.quiknode.pro/5dfad2e854856d15e94921a6b07aa95e80b35a73/');
    return true;
  }
  return false;
};

const initialize = () => {
  inputPdAddress.value = config.contractAddress;

  buttonEthEnable.addEventListener('click', () => {
    ethEnable().then((result) => {
      labelEthAccount.textContent = result ? 'Address: ' + window.accounts[0] : 'Can`t connect';
      buttonEthEnable.disabled = result;
      buttonEthEnable.textContent = 'CONNECTED';
      if (result) {
        window.profitDivider = new window.web3.eth.Contract(config.abi, inputPdAddress.value);
        window.profitDivider.methods
          .symbol()
          .call()
          .then((result) => (window.symbol = result));
        initEventListeners();
        window.profitDividerWss = new window.web3_wss.eth.Contract(config.abi, inputPdAddress.value);
        if (window.profitDividerWss) {
          initContractEventsListener();
        }
      }
    });
  });
};
window.addEventListener('DOMContentLoaded', initialize);

const initEventListeners = () => {
  buttonMyBalance.addEventListener('click', async () => {
    labelMyBalance.textContent = await window.profitDivider.methods.balanceOf(window.accounts[0]).call();
    labelMyBalance.textContent += ' ' + symbol;
  });

  buttonContractOwner.addEventListener('click', async () => {
    labelContractOwner.textContent = await window.profitDivider.methods.owner().call();
  });

  buttonContractBalanceOf.addEventListener('click', async () => {
    if (!inputContractBalanceOf.value) return;
    labelContractBalanceOf.textContent = await window.profitDivider.methods.balanceOf(inputContractBalanceOf.value).call();
    labelContractBalanceOf.textContent += ' ' + symbol;
  });

  buttonContractAccumulatedPfofit.addEventListener('click', async () => {
    labelContractAccumulatedPfofit.textContent = await window.profitDivider.methods.accumulatedPfofit().call();
  });
};

const initContractEventsListener = () => {
  /**
   * Update AccumulatedPfofit
   */
  profitDividerWss.events.AccumulatedPfofitChanged().on('data', function (event) {
    labelContractAccumulatedPfofit.textContent = parseInt(event.raw.data, 16);
  });
};
