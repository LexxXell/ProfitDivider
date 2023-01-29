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
  const buttonEthEnable = document.getElementById('button-eth-enable');
  const labelEthAccount = document.getElementById('label-eth-account');
  const inputPdAddress = document.getElementById('input-pd-address');

  inputPdAddress.value = config.contractAddress;

  buttonEthEnable.addEventListener('click', () => {
    ethEnable().then((result) => {
      labelEthAccount.textContent = result ? window.accounts[0] : 'Can`t connect';
      buttonEthEnable.disabled = result;
      if (result) {
        window.profitDivider = new window.web3.eth.Contract(config.abi, inputPdAddress.value);
      }
    });
  });
};
window.addEventListener('DOMContentLoaded', initialize);
