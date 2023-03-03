import config from './config.js';

const buttonEthEnable = document.getElementById('button-eth-enable');
const labelEthAccount = document.getElementById('label-eth-account');
const inputPdAddress = document.getElementById('input-pd-address');
const labelEthName = document.getElementById('label-eth-name');
const labelEthSymbol = document.getElementById('label-eth-symbol');
const labelEthTotalSupply = document.getElementById('label-eth-totalSupply');
const labelEthOwner = document.getElementById('label-eth-owner');
const labelEthAdministrator = document.getElementById('label-eth-administrator');
const labelEthAdministratorContact = document.getElementById('label-eth-administratorContact');
const buttonEthUpdatePublicState = document.getElementById('button-eth-updatePublicState');
const inputEthBalanceOfAddress = document.getElementById('input-eth-balanceOf');
const labelEthBalanceOf = document.getElementById('label-eth-balanceOf');
const buttonEthBalanceOf = document.getElementById('button-eth-balanceOf');

const ethEnable = async () => {
  if (window.ethereum) {
    window.accounts = await window.ethereum.request({
      method: 'eth_requestAccounts',
    });
    window.web3 = new Web3(window.ethereum);
    window.web3wss = new Web3(config.wssProviderUrl);
    return true;
  }
  return false;
};

const initChainNetwork = async () => {
  try {
    await ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: config.chainParams.chainId }],
    });
    return true;
  } catch (switchError) {
    // This error code indicates that the chain has not been added to MetaMask.
    if (switchError.code === 4902) {
      try {
        await ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [config.chainParams],
        });
        return true;
      } catch (addError) {
        // handle "add" error
        return false;
      }
    }
    // handle other "switch" errors
    return false;
  }
};

const initContract = async () => {
  window.profitDivider = new window.web3.eth.Contract(config.abi, inputPdAddress.value);
  window.profitDividerWss = new window.web3.eth.Contract(config.abi, inputPdAddress.value);
  try {
    return (await profitDivider.methods.symbol().call()) === (await profitDividerWss.methods.symbol().call());
  } catch (e) {
    console.error(e);
    return false;
  }
};

const getContractTokenName = () => profitDivider.methods.name().call();
const getContractTokenSymbol = () => profitDivider.methods.symbol().call();
const getContractTotalSupply = () => profitDivider.methods.totalSupply().call();
const getContractOwner = () => profitDivider.methods.owner().call();
const getContractAdministrator = () => profitDivider.methods.adminisrator().call();
const getContractAdministratorContact = () => profitDivider.methods.adminisratorContact().call();

const getContractBalanceOf = (account) => profitDivider.methods.balanceOf(account).call();

const updatePublicContractState = async () => {
  labelEthName.textContent = await getContractTokenName();
  labelEthSymbol.textContent = await getContractTokenSymbol();
  labelEthTotalSupply.textContent = await getContractTotalSupply();
  labelEthOwner.textContent = await getContractOwner();
  labelEthAdministrator.textContent = await getContractAdministrator();
  labelEthAdministratorContact.textContent = (await getContractAdministratorContact()) || 'no contact';
};

const initialize = () => {
  inputPdAddress.value = config.contractAddress;

  buttonEthEnable.addEventListener('click', async () => {
    buttonEthEnable.disabled = true;
    buttonEthEnable.textContent = 'Connecting...';
    if (await ethEnable()) {
      await initChainNetwork();
      if (await initContract()) {
        buttonEthEnable.textContent = 'CONNECTED';
        labelEthAccount.textContent = window.accounts[0];
      }
    } else {
      buttonEthEnable.disabled = false;
      buttonEthEnable.textContent = 'connect';
      throw new Error('Can`t connect to wallet');
    }
  });

  buttonEthUpdatePublicState.addEventListener('click', () => {
    updatePublicContractState();
  });

  buttonEthBalanceOf.addEventListener('click', () => {
    if (!web3.utils.isAddress(inputEthBalanceOfAddress.value)) {
      alert('Specify address');
    } else getContractBalanceOf(inputEthBalanceOfAddress.value).then((result) => (labelEthBalanceOf.textContent = result));
  });
};
window.addEventListener('DOMContentLoaded', initialize);
