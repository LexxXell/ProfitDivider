// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Moderated is Ownable {
  mapping(address => bool) private _isModerator;

  modifier onlyModerator() {
    _checkModerator();
    _;
  }

  function addModerator(address moderator) external virtual onlyOwner {
    _addModerator(moderator);
  }

  function deleteModerator(address moderator) external virtual onlyOwner {
    _deleteModerator(moderator);
  }

  function isModerator() external view virtual returns (bool) {
    return _isModerator[_msgSender()];
  }

  function _checkModerator() internal view virtual {
    require(
      _isModerator[_msgSender()] || owner() == _msgSender(),
      "Moderated: caller is not the moderator"
    );
  }

  function _addModerator(address moderator) private {
    _isModerator[moderator] = true;
  }

  function _deleteModerator(address moderator) private {
    _isModerator[moderator] = false;
  }
}
