// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./access/administrated.sol";
import "./apps/votings.sol";

contract ProfitDivider is ERC20, Ownable, Administrated, Votings, ReentrancyGuard {
  uint256 private _totalSupply;

  uint256 private _disrtibuteVotingId;

  struct DividendsWithdrawError {
    uint256 blockNumber;
    uint256 dividends;
  }
  mapping(address => DividendsWithdrawError[]) private _withdrawErrors;
  mapping(address => uint256) private _withdrawErrorsCount;

  uint256 private _accumulatedPfofit;
  uint256 private _accumulatedPfofitThreshold;
  mapping(address => uint256) private _dividends;

  address[] private _holders;
  mapping(address => uint256) private _addressToHolderId;

  event AccumulatedPfofitChanged(uint256 newValue);
  event AccumulatedPfofitThresholdChanged(uint256 newValue);
  event WithdrawErrorOccurred(address account, uint256 errorId);
  event DividendsDistributed();
  event DisrtibuteVotesThresholdChanged(uint256 newValue);

  constructor(
    string memory token_name,
    string memory token_symbol,
    uint256 total_supply,
    uint256 profit_threshold,
    uint256 voting_threshold
  ) ERC20(token_name, token_symbol) {
    _totalSupply = total_supply;
    _accumulatedPfofitThreshold = profit_threshold;
    _disrtibuteVotingId = createVoting("Dividends distribution vote", voting_threshold);
    _mint(msg.sender, _totalSupply);
  }

  receive() external payable {
    _setAccumulatedPfofit(_accumulatedPfofit + msg.value);
    if (_accumulatedPfofit >= _accumulatedPfofitThreshold) {
      _disrtibute();
    }
  }

  function accumulatedPfofit() external view returns (uint256) {
    return _accumulatedPfofit;
  }

  function accumulatedPfofitThreshold() external view returns (uint256) {
    return _accumulatedPfofitThreshold;
  }

  function setAccumulatedPfofitThreshold(uint256 value) external onlyOwner {
    _accumulatedPfofitThreshold = value;
    emit AccumulatedPfofitThresholdChanged(_accumulatedPfofitThreshold);
  }

  function dividends() external view returns (uint256) {
    return _dividends[_msgSender()];
  }

  function dividendsOf(address account) external view onlyAdministrator returns (uint256) {
    return _dividends[account];
  }

  function forceDistribute() external onlyAdministrator {
    _disrtibute();
  }

  function withdrawErrorsAll(address account)
    external
    view
    onlyAdministrator
    returns (DividendsWithdrawError[] memory)
  {
    return _withdrawErrors[account];
  }

  function withdrawErrorsById(address account, uint256 errorId)
    external
    view
    onlyAdministrator
    returns (DividendsWithdrawError memory)
  {
    return _withdrawErrors[account][errorId];
  }

  function decimals() public pure override returns (uint8) {
    return 0;
  }

  function disrtibuteVotes() external view returns (uint256) {
    return votes(_disrtibuteVotingId);
  }

  function disrtibuteVotesThreshold() external view returns (uint256) {
    return votingThreshold(_disrtibuteVotingId);
  }

  function setDisrtibuteVotesThreshold(uint256 value) external onlyOwner {
    setVotingThreshold(_disrtibuteVotingId, value);
    emit DisrtibuteVotesThresholdChanged(value);
  }

  function disrtibuteVoteRequiest() external {
    _disrtibuteVoteRequiest();
  }

  function withrawDividends(uint256 value) external {
    _withdrawDividendsTo(payable(_msgSender()), value);
  }

  function withrawAllDividends() external {
    _withdrawDividendsTo(payable(_msgSender()), _dividends[_msgSender()]);
  }

  function withrawDividendsTo(address payable to, uint256 value) external {
    _withdrawDividendsTo(to, value);
  }

  function _withdrawDividendsTo(address payable to, uint256 value) private nonReentrant {
    require(
      _dividends[_msgSender()] >= value,
      "_withrawDividends: not enough dividends to withdraw the specified amount."
    );
    _dividends[_msgSender()] -= value;
    (bool success, ) = to.call{value: value}("");
    if (!success) {
      _dividends[_msgSender()] += value;
      _withdrawErrors[_msgSender()].push(DividendsWithdrawError(block.number, value));
      emit WithdrawErrorOccurred(_msgSender(), _withdrawErrorsCount[_msgSender()]);
      _withdrawErrorsCount[_msgSender()] += 1;
    }
    require(success, "_withrawDividends: error when trying to withdraw dividends.");
  }

  function _setAccumulatedPfofit(uint256 value) private {
    _accumulatedPfofit = value;
    emit AccumulatedPfofitChanged(_accumulatedPfofit);
  }

  function _disrtibute() private {
    uint256 profitPerToken = _profitPerToken();
    require(profitPerToken > 0, "_disrtibute: accumulated pfofit is too small to distribute.");
    for (uint256 i; i < _holders.length; ) {
      address account = _holders[i];
      uint256 balance = balanceOf(account);
      if (balance > 0) {
        uint256 profit = profitPerToken * balance;
        _dividends[account] += profit;
        _setAccumulatedPfofit(_accumulatedPfofit - profit);
      }
      // prettier-ignore
      unchecked { i++; }
    }
    emit DividendsDistributed();
  }

  function _disrtibuteVoteRequiest() private {
    bool result = addVotes(_disrtibuteVotingId, balanceOf(_msgSender()));
    if (result) {
      _disrtibute();
      clearVoting(_disrtibuteVotingId);
    }
  }

  function _profitPerToken() private view returns (uint256) {
    return (_accumulatedPfofit - (_accumulatedPfofit % _totalSupply)) / _totalSupply;
  }

  function _beforeTokenTransfer(
    address, /*from*/
    address to,
    uint256 /*amount*/
  ) internal override {
    if (balanceOf(to) == 0) {
      _addressToHolderId[to] = _holders.length;
      _holders.push(to);
    }
  }

  function _afterTokenTransfer(
    address from,
    address, /*to*/
    uint256 /*amount*/
  ) internal override {
    if (balanceOf(from) == 0) {
      uint256 id = _addressToHolderId[from];
      delete _addressToHolderId[from];
      _holders[id] = _holders[_holders.length - 1];
      _holders.pop();
    }
  }
}
