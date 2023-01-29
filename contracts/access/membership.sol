// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract Membership is Context {
  mapping(address => bool) private _isMember;
  address payable[] internal _members;
  uint256 private _count;

  modifier onlyMember() {
    _checkMember();
    _;
  }

  function membersCount() internal view virtual returns (uint256) {
    return _count;
  }

  function isMember(address account) internal view virtual returns (bool) {
    return _isMember[account];
  }

  function addMember(address account) internal virtual {
    _isMember[account] = true;
    _members.push(payable(account));
    _count++;
  }

  function _checkMember() internal view virtual {
    require(_isMember[_msgSender()], "Membership: caller is not the member");
  }
}
