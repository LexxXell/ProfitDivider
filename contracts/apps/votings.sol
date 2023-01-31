// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract Votings is Context {
  uint256 private _voteThreshold;

  struct Voting {
    string name;
    uint256 votes;
    uint256 threshold;
    address[] votedAccounts;
    mapping(address => bool) isVoted;
  }

  mapping(uint256 => Voting) private _votings;
  uint256 private _nextVotingsId;

  event VotingCreated(uint256 id);
  event VotingSuccessful(uint256 id);
  event VotingCleared(uint256 id);

  function votingThreshold(uint256 votingId) public view returns (uint256) {
    return _votings[votingId].threshold;
  }

  function setVotingThreshold(uint256 votingId, uint256 value) internal {
    _votings[votingId].threshold = value;
  }

  function createVoting(string memory name, uint256 threshold) internal returns (uint256) {
    return _createVoting(name, threshold);
  }

  function addVotes(uint256 votingId, uint256 value) public returns (bool) {
    return _addVotes(votingId, value);
  }

  function votes(uint256 votingId) public view returns (uint256) {
    return _votings[votingId].votes;
  }

  function clearVoting(uint256 votingId) internal {
    _clearVoting(votingId);
  }

  function _createVoting(string memory name, uint256 threshold) private returns (uint256) {
    uint256 id = _nextVotingsId;
    _nextVotingsId++;
    Voting storage newVoting = _votings[id];
    newVoting.name = name;
    newVoting.threshold = threshold;
    emit VotingCreated(id);
    return id;
  }

  function _addVotes(uint256 votingId, uint256 value) private returns (bool) {
    require(!_votings[votingId].isVoted[_msgSender()], "_addVotes: you already voted");
    _votings[votingId].votes += value;
    _votings[votingId].votedAccounts.push(_msgSender());
    _votings[votingId].isVoted[_msgSender()] = true;
    if (_votings[votingId].votes >= _voteThreshold) {
      emit VotingSuccessful(votingId);
    }
    return _votings[votingId].votes >= _votings[votingId].threshold;
  }

  function _clearVoting(uint256 votingId) private {
    Voting storage voting = _votings[votingId];
    for (uint256 i; i < voting.votedAccounts.length; ) {
      delete voting.isVoted[voting.votedAccounts[i]];
      // prettier-ignore
      unchecked { i++; }
    }
    delete voting.votedAccounts;
    voting.votes = 0;
    emit VotingCleared(votingId);
  }
}
