import config from './config.js';

const ethEnable = async () => {
  if (window.ethereum) {
    window.accounts = await window.ethereum.request({
      method: 'eth_requestAccounts',
    });
    window.web3 = new Web3(window.ethereum);
    return true;
  }
  return false;
};

const initialize = () => {
  let symbol = '';

  const buttonEthEnable = document.getElementById('button-eth-enable');
  const buttonMyBalance = document.getElementById('button-contract-myBalance');
  const labelEthAccount = document.getElementById('label-eth-account');
  const labelMyBalance = document.getElementById('label-contract-myBalance');
  const inputPdAddress = document.getElementById('input-pd-address');

  const buttonContractOwner = document.getElementById('button-contract-owner');
  const labelContractOwner = document.getElementById('label-contract-owner');

  const inputContractBalanceOf = document.getElementById('input-contract-balanceOf');
  const buttonContractBalanceOf = document.getElementById('button-contract-balanceOf');
  const labelContractBalanceOf = document.getElementById('label-contract-balanceOf');

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
          .then((result) => (symbol = result));
      }
    });
  });

  buttonMyBalance.addEventListener('click', async () => {
    labelMyBalance.textContent = await window.profitDivider.methods
      .balanceOf(window.accounts[0])
      .call();
    labelMyBalance.textContent += ' ' + symbol;
  });

  buttonContractOwner.addEventListener('click', async () => {
    labelContractOwner.textContent = await window.profitDivider.methods.owner().call();
  });

  buttonContractBalanceOf.addEventListener('click', async () => {
    if (!inputContractBalanceOf.value) return;
    labelContractBalanceOf.textContent = await window.profitDivider.methods
      .balanceOf(inputContractBalanceOf.value)
      .call();
    labelContractBalanceOf.textContent += ' ' + symbol;
  });
};
window.addEventListener('DOMContentLoaded', initialize);
