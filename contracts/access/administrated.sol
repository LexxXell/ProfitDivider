// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Administrated is Ownable {
  event AddedAdministrator(address account);
  event DeletedAdministrator(address account);
  event DeletedAllAdministrators();

  address[] private _administrators;
  mapping(address => uint256) private _addressToAdministratorId;

  modifier onlyAdministrator() {
    _checkAdministrator();
    _;
  }

  function isAdministrator() external view virtual returns (bool) {
    return _isAdministrator(_msgSender());
  }

  function addAdministrator(address account) external virtual onlyOwner {
    _addAdministrator(account);
  }

  function deleteAdministrator(address account) external virtual onlyOwner {
    _deleteAdministrator(account);
  }

  function deleteAllAdministrators() external virtual onlyOwner {
    _deleteAllAdministrators();
  }

  function _checkAdministrator() internal view virtual {
    require(
      _isAdministrator(_msgSender()) || owner() == _msgSender(),
      "Administrated: caller is not the administrator"
    );
  }

  function _addAdministrator(address account) private {
    _administrators.push(account);
    _addressToAdministratorId[account] = _administrators.length;
    emit AddedAdministrator(account);
  }

  function _deleteAdministrator(address account) private {
    uint256 id = _addressToAdministratorId[account] - 1;
    _administrators[id] = _administrators[_administrators.length - 1];
    _administrators.pop();
    delete _addressToAdministratorId[account];
    emit DeletedAdministrator(account);
  }

  function _deleteAllAdministrators() private {
    for (uint256 i = 0; i < _administrators.length; ) {
      delete _addressToAdministratorId[_administrators[i]];
      // prettier-ignore
      unchecked { i++; }
    }
    delete _administrators;
    emit DeletedAllAdministrators();
  }

  function _isAdministrator(address account) private view returns (bool) {
    return _addressToAdministratorId[account] > 0;
  }
}
