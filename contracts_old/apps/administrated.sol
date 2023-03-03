// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Administrated is Ownable {
  address private _administrator;
  string private _administratorContact;

  event AdministratorChanged(address newAdministrator, string newAdministratorContact);

  modifier onlyAdministrator() {
    require(
      owner() == _msgSender() || adminisrator() == _msgSender(),
      "Forbidden: caller is not the administrator"
    );
    _;
  }

  function adminisrator() public view virtual returns (address) {
    return _administrator;
  }

  function adminisratorContact() public view virtual returns (string memory) {
    return _administratorContact;
  }

  function setAdminisrator(address newAdministrator, string memory newAdministratorContact)
    public
    virtual
    onlyOwner
  {
    _administrator = newAdministrator;
    _administratorContact = newAdministratorContact;
  }
}
