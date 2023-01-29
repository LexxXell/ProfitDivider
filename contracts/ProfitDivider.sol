// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./access/membership.sol";
import "./access/moderated.sol";

contract ProfitDivider is ERC20, Ownable, Moderated, Membership, ReentrancyGuard {
  uint256 private _totalSupply;

  struct DividendsPaymentError {
    uint256 blockNumber;
    uint256 dividends;
  }
  mapping(address => DividendsPaymentError[]) private _paymentErrors;

  uint256 private _accumulatedPfofit;
  uint256 private _accumulatedPfofitThreshold;
  mapping(address => uint256) private _dividends;

  uint256 private _collegialDisrtibuteStake;
  uint256 private _collegialDisrtibuteVotesCount;
  address[] private _votes;
  mapping(address => bool) private _isCollegialDisrtibuteVoted;
  uint256 private _collegialDecisionStakeThreshold;

  constructor() ERC20("ProfitDividerByXell", "PDBX") {
    _totalSupply = 100000;
    _accumulatedPfofitThreshold = 1 ether;
    _collegialDecisionStakeThreshold = 20000; // in tokens part of _totalSupply
    _mint(msg.sender, _totalSupply);
  }

  receive() external payable {
    _accumulatedPfofit += msg.value;
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
  }

  function dividends(address account) external view returns (uint256) {
    return _dividends[account];
  }

  function forceDistribute() external onlyModerator {
    _disrtibute();
  }

  function decimals() public pure override returns (uint8) {
    return 0;
  }

  function collegialDisrtibuteStake() external view onlyMember returns (uint256) {
    return _collegialDisrtibuteStake;
  }

  function collegialDistributeRequiest() external {
    _collegialDisrtibuteRequest();
  }

  function withrawDividends(uint256 value) external onlyMember {
    _withdrawDividendsTo(payable(_msgSender()), value);
  }

  function withrawAllDividends() external onlyMember {
    _withdrawDividendsTo(payable(_msgSender()), _dividends[_msgSender()]);
  }

  function withrawDividendsTo(address payable to, uint256 value) external onlyMember {
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
      _paymentErrors[_msgSender()].push(DividendsPaymentError(block.number, value));
    }
    require(success, "_withrawDividends: error when trying to withdraw dividends.");
  }

  function _disrtibute() private {
    uint256 profitPerToken = _profitPerToken();
    require(profitPerToken > 0, "_disrtibute: accumulated pfofit is too small to distribute.");
    for (uint256 i; i < membersCount(); ) {
      address account = _members[i];
      uint256 balance = balanceOf(account);
      _isCollegialDisrtibuteVoted[account] = false;
      if (balance > 0) {
        uint256 profit = profitPerToken * balance;
        _dividends[account] += profit;
        _accumulatedPfofit -= profit;
      }
      // prettier-ignore
      unchecked { i++; }
    }
    _collegialDisrtibuteVotesCount = 0;
    _collegialDisrtibuteStake = 0;
  }

  function _collegialDisrtibuteRequest() private onlyMember {
    require(
      !_isCollegialDisrtibuteVoted[_msgSender()],
      "_collegialDisrtibuteRequest: you already voted "
    );
    _collegialDisrtibuteStake += balanceOf(_msgSender());
    if (_collegialDisrtibuteStake >= _collegialDecisionStakeThreshold) {
      _clearCollegialDisrtibuteRequest();
      _disrtibute();
    }
  }

  function _clearCollegialDisrtibuteRequest() private {
    for (uint256 i; i < _collegialDisrtibuteVotesCount; ) {
      _isCollegialDisrtibuteVoted[_votes[i]] = false;
      // prettier-ignore
      unchecked { i++; }
    }
    _collegialDisrtibuteVotesCount = 0;
    _collegialDisrtibuteStake = 0;
  }

  function _profitPerToken() private view returns (uint256) {
    return (_accumulatedPfofit - (_accumulatedPfofit % _totalSupply)) / _totalSupply;
  }

  function _afterTokenTransfer(
    address, /*from*/
    address to,
    uint256 /*amount*/
  ) internal override {
    if (!isMember(to)) {
      addMember(to);
    }
  }
}
