// SPDX-License-Identifier: AFPL

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract ProfitDivider is Context, ReentrancyGuard {
  // Комиссонные
  uint256 private _commission;
  uint256 private _minCommissionToDivide;
  // При выводе средств будет взиматьси комиссия
  uint16 private _withdrawCommissionParts;
  uint16 private _withdrawCommissionMaxPart;
  // Делитель для комиссии
  uint16 private _commissionBaseParts;
  // Плата за добавление нового incomeAddress
  uint256 private _addIncomeAddressFee;
  // Плата за переименование компании
  uint256 private _renameCompanyFee;

  // Максимальная цена за установку URI
  uint256 private _uriMaxFee; // 0.1 ether
  // Минимальная длина URI
  uint256 private _uriMinLength;
  // Максимальная длина URI
  uint256 private _uriMaxLength;
  // Длина URI с которой установка бесплатная
  uint256 private _freeUriLength;

  struct Company {
    address owner;
    string name; // Строка типа <[Company Name]>
    string contacts; // Строка типа <[{tg}@test{em}test@test.test{loc}Surakul Stadium, Phuket, Thailand{gh}https://github.com/ProfitDivider/]>
    uint256 createdAt;
    // Если передача акций происходит новому холдеру, то взимется комиссия,
    // это необходимо для ограничения торговли акциями вне круга холдеров,
    // тем самым сдерживая его рост, дабы не росла комиссия за поступление средств.
    uint256 invitationFee;
    uint256 totalShares;
    uint256 totalProfit; // Общая прибыль за всё время
    uint256 accumulatedProfit; // Размер текуще накопленной прибыли
    uint256 latestIncomingCash; // Размер последнего поступления
    uint256 latestIncomingCashDate; // Дата последнего поступления
    uint8 maxHolders; // Максимум 256 холдеров. Это сделано, для снижения цены комиссии при переводах
    address[] holders;
    address[] incomingAddresses;
    mapping(address => uint256) incomeAddressToId;
    mapping(address => uint256) addressToHolderId;
    mapping(address => uint256) balances;
    mapping(address => uint256) dividends;
  }

  struct CompanyInfo {
    bytes32 id;
    address owner;
    string name;
    string contacts;
    uint256 createdAt;
    uint256 invitationFee;
    uint256 totalShares;
    uint256 totalProfit;
    uint256 accumulatedProfit;
    uint256 latestIncomingCash;
    uint256 latestIncomingCashDate;
    uint8 maxHolders;
    uint256 holdersCount;
    uint256 balance;
    uint256 dividends;
  }

  uint256 private _companiesCount;
  mapping(bytes32 => Company) private _companies;
  mapping(address => bytes32) private _incomeAddress;

  mapping(address => bytes32[]) private _accountCompanyIds;
  mapping(address => mapping(bytes32 => uint256)) private _accountCompanyIdtoIndex;

  mapping(address => bool) private _isPrivateAccount;

  mapping(address => uint256) private _totalProfit;

  mapping(string => bytes32) private _uriToId;

  event Transfer(bytes32 id, address indexed from, address indexed to, uint256 value);
  event CreateCompany(bytes32 indexed id);
  event OwnershipTransferred(bytes32 indexed id, address indexed previousOwner, address indexed newOwner);
  event ProfitUpdated(uint256 value);
  event IncomingCash(bytes32 indexed id, uint256 value);
  event WithdrawCommissionChanged(uint256 value);
  event CompanyContactsChanged(string indexed oldContacts, string indexed newContacts);
  event CompanyNameChanged(string indexed oldName, string indexed newName);
  event InvitationFeeChanged(bytes32 indexed id, uint256 value);
  event MaxHoldersChanged(bytes32 indexed id, uint256 value);
  event AddedCompanyToAccountList(bytes32 indexed id, address indexed account);
  event RemovedCompanyToAccountList(bytes32 indexed id, address indexed account);
  event DividendsWithdrawed(bytes32 indexed id, address indexed account, uint256 value);
  event TotalDividendsWithdrawed(address indexed account, uint256 value);
  event HoldersAmountUpdated(bytes32 indexed id, uint256 value);

  modifier onlyOwner(bytes32 id) {
    _checkOwner(id);
    _;
  }

  modifier onlyPartner(bytes32 id) {
    _checkPartner(id);
    _;
  }

  modifier validUri(string memory uri) {
    require(_checUri(uri), "ProfitDivider: invalid URI");
    _;
  }

  constructor() {
    _withdrawCommissionMaxPart = 25; // 2.5%

    _withdrawCommissionParts = 5; // 0.5%
    _commissionBaseParts = 1000;
    _addIncomeAddressFee = 10000000000000000; // 0.01 Eth
    _renameCompanyFee = 10000000000000000; // 0.01 Eth
    _minCommissionToDivide = 100000000000000000; // 0.1 Eth

    _uriMaxFee = 100000000000000000; // 0.1 ether
    _uriMinLength = 3;
    _uriMaxLength = 32;
    _freeUriLength = 9;

    _createCompany(0x0, "<[ProfitDivider]>", "<[{tg}@lexxxell{gh}https://github.com/LexxXell]>", 1000, 8, address(this));
  }

  receive() external payable {
    bytes32 id = _incomeAddress[_msgSender()];
    _incomingCash(id, msg.value);
  }

  function incomingCash(bytes32 id) external payable {
    _incomingCash(id, msg.value);
  }

  function createCompany(
    string memory name,
    string memory contacts,
    uint256 totalShares,
    uint8 maxHolders,
    address incomeAddress
  ) external returns (bytes32) {
    return _createCompany(_newCompanyId(name), name, contacts, totalShares, maxHolders, incomeAddress);
  }

  function myCompanyIds() external view returns (bytes32[] memory) {
    return _myCompanyIds();
  }

  function myTotalProfit() external view returns (uint256) {
    return _totalProfit[_msgSender()];
  }

  function companyInfoById(bytes32 id) external view returns (CompanyInfo memory) {
    return _companyInfo(id);
  }

  function companyInfoByUri(string memory uri) external view returns (CompanyInfo memory) {
    return _companyInfo(_uriToId[uri]);
  }

  function companyIncomeAddresses(bytes32 id) external view onlyOwner(id) returns (address[] memory) {
    return _companyIncomeAddresses(id);
  }

  function companyHoldersInfo(bytes32 id) external view onlyPartner(id) returns (address[] memory, uint256[] memory) {
    return _companyHoldersInfo(id);
  }

  function myTotalDivivends() external view returns (uint256) {
    return _myTotalDividends();
  }

  function withdrawDividends(bytes32 id) external nonReentrant {
    _withdrawAllDividends(id);
  }

  function checkRequiredInvtationFee(bytes32 id, address account) external view returns (bool) {
    return _checkRequiredInvtationFee(id, account);
  }

  function transfer(
    bytes32 id,
    address to,
    uint256 value
  ) external payable {
    _transfer(id, _msgSender(), to, value, msg.value);
  }

  function leaveCompany(bytes32 id) external {
    _transfer(id, _msgSender(), _companies[id].owner, _companies[id].balances[_msgSender()], 0);
  }

  function owner() external view returns (address) {
    return _companies[0x0].owner;
  }

  function accountPrivacyStatus() external view returns (bool) {
    return _accountPrivacyStatus();
  }

  function changeAccountPrivacy() external returns (bool) {
    return _changeAccountPrivacy();
  }

  function getWithdrawCommission() external view returns (uint16, uint16) {
    return (_withdrawCommissionParts, _commissionBaseParts);
  }

  function addIncomeAddressFee() external view returns (uint256) {
    return _addIncomeAddressFee;
  }

  function renameCompanyFee() external view returns (uint256) {
    return _renameCompanyFee;
  }

  function calculateUriFee(string memory uri) external view validUri(uri) returns (uint256) {
    return _uriFee(bytes(uri).length);
  }

  function setWithdrawCommission(uint16 value) external onlyOwner(0x0) {
    _setWithdrawCommission(value);
  }

  function setRenameCompanyFee(uint256 value) external onlyOwner(0x0) {
    _setRenameCompanyFee(value);
  }

  function setMaxUriFee(uint256 value) external onlyOwner(0x0) {
    _uriMaxFee = value;
  }

  function setMinProfitToDivide(uint256 value) external onlyOwner(0x0) {
    _setMinProfitToDivide(value);
  }

  function divideProfit() external onlyPartner(0x0) {
    _divideCommission();
  }

  function profit() external view onlyPartner(0x0) returns (uint256) {
    return _commission;
  }

  function transferOwnership(bytes32 id, address to) external onlyOwner(id) {
    _transferOwnership(id, to);
  }

  function renounceOwnership(bytes32 id) external onlyOwner(id) {
    _transferOwnership(id, address(0));
  }

  function addIncomeAddress(bytes32 id, address incomeAddress) external payable onlyOwner(id) {
    _addIncomeAddressPayable(id, incomeAddress, msg.value);
  }

  function deleteIncomeAddress(bytes32 id, address incomeAddress) external onlyOwner(id) {
    _deleteIncomeAddress(id, incomeAddress);
  }

  function setUri(bytes32 id, string memory uri) external payable onlyOwner(id) validUri(uri) {
    require(msg.value >= _uriFee(bytes(uri).length), "ProfitDivider: too small fee");
    _uriToId[uri] = id;
  }

  function removeUri(bytes32 id, string memory uri) external onlyOwner(id) validUri(uri) {
    delete _uriToId[uri];
  }

  function changeContacts(bytes32 id, string memory newContacts) external onlyOwner(id) {
    _changeContacts(id, newContacts);
  }

  function renameCompany(bytes32 id, string memory newName) external payable onlyOwner(id) {
    _renameCompany(id, newName, msg.value);
  }

  function setInvitationFee(bytes32 id, uint256 value) external onlyOwner(id) {
    _setInvitationFee(id, value);
  }

  function setMaxHolders(bytes32 id, uint8 value) external onlyOwner(id) {
    _setMaxHolders(id, value);
  }

  /* ==================================== */

  function _createCompany(
    bytes32 id,
    string memory name,
    string memory contacts,
    uint256 totalShares,
    uint8 maxHolders,
    address incomeAddress
  ) private returns (bytes32) {
    Company storage company = _companies[id];
    company.owner = _msgSender();
    company.name = name;
    company.contacts = contacts;
    company.createdAt = block.timestamp;
    company.invitationFee = 0;
    company.maxHolders = maxHolders;
    _addIncomeAddress(id, incomeAddress);
    _mint(id, _msgSender(), totalShares == 0 ? 1 : totalShares);
    emit CreateCompany(id);
    return id;
  }

  function _checkOwner(bytes32 id) internal view virtual {
    require(_companies[id].owner == _msgSender(), "ProfitDivider: caller is not the owner of this company");
  }

  function _checkPartner(bytes32 id) internal view virtual {
    require(
      _companies[id].owner == _msgSender() || _companies[id].addressToHolderId[_msgSender()] > 0,
      "ProfitDivider: caller is not the partner of this company"
    );
  }

  function _checkRequiredInvtationFee(bytes32 id, address account) private view returns (bool) {
    return _companies[id].balances[account] == 0;
  }

  function _checkContractBalance(uint256 value) private view {
    require(address(this).balance >= value, "ProfitDivider: the contract balance is less than the requested value.");
  }

  function _myCompanyIds() private view returns (bytes32[] memory) {
    return _accountCompanyIds[_msgSender()];
  }

  function _companyInfo(bytes32 id) private view returns (CompanyInfo memory) {
    Company storage company = _companies[id];
    CompanyInfo memory company_info;

    company_info.id = id;
    company_info.owner = company.owner;
    company_info.name = company.name;
    company_info.contacts = company.contacts;
    company_info.createdAt = company.createdAt;
    company_info.invitationFee = company.invitationFee;
    company_info.totalShares = company.totalShares;
    company_info.totalProfit = company.totalProfit;
    company_info.accumulatedProfit = company.accumulatedProfit;
    company_info.latestIncomingCash = company.latestIncomingCash;
    company_info.latestIncomingCashDate = company.latestIncomingCashDate;
    company_info.maxHolders = company.maxHolders;
    company_info.holdersCount = company.holders.length;
    company_info.balance = _balanceOf(id, _msgSender());
    company_info.dividends = _dividendsOf(id, _msgSender());

    return company_info;
  }

  function _companyIncomeAddresses(bytes32 id) private view returns (address[] memory) {
    return _companies[id].incomingAddresses;
  }

  function _companyHoldersInfo(bytes32 id) private view returns (address[] memory, uint256[] memory) {
    address[] memory partners = _companies[id].holders;
    uint256[] memory balances;
    for (uint256 i = 0; i < partners.length; ) {
      balances[i] = (_balanceOf(id, partners[i]));
      // prettier-ignore
      unchecked { i++; }
    }
    return (partners, balances);
  }

  function _myTotalDividends() private view returns (uint256) {
    uint256 dividends;
    bytes32[] memory my_company_ids = _myCompanyIds();

    for (uint256 i; i < my_company_ids.length; ) {
      dividends += _dividendsOf(my_company_ids[i], _msgSender());
      // prettier-ignore
      unchecked { i++; }
    }

    return dividends;
  }

  function _newCompanyId(string memory name) private returns (bytes32) {
    return keccak256(abi.encode(_msgSender(), name, _companiesCount++));
  }

  function _addIncomeAddressPayable(
    bytes32 id,
    address incomeAddress,
    uint256 pay
  ) private {
    _payFee(pay, _addIncomeAddressFee);
    _addIncomeAddress(id, incomeAddress);
  }

  function _addIncomeAddress(bytes32 id, address incomeAddress) private {
    require(_incomeAddress[incomeAddress] == 0x0, "ProfitDivider: the specified address is already in use");
    _incomeAddress[incomeAddress] = id;
    _companies[id].incomeAddressToId[incomeAddress] = _companies[id].incomingAddresses.length;
    _companies[id].incomingAddresses.push(incomeAddress);
  }

  function _deleteIncomeAddress(bytes32 id, address incomeAddress) private {
    require(_incomeAddress[incomeAddress] == id, "ProfitDivider: the specified address is not associated with the specified ID.");
    _incomeAddress[incomeAddress] = 0x0;
    uint256 index = _companies[id].incomeAddressToId[incomeAddress];
    delete _companies[id].incomeAddressToId[incomeAddress];
    _companies[id].incomingAddresses[index] = _companies[id].incomingAddresses[_companies[id].incomingAddresses.length - 1];
    _companies[id].incomingAddresses.pop();
  }

  function _transferOwnership(bytes32 id, address to) private {
    if (_balanceOf(id, _msgSender()) == 0) {
      _removeCompanyFromAccountsList(id, _msgSender());
    }
    if (_balanceOf(id, to) == 0) {
      _addCompanyToAccountsList(id, to);
    }
    _companies[id].owner = to;
    emit OwnershipTransferred(id, _msgSender(), to);
  }

  function _balanceOf(bytes32 id, address account) private view returns (uint256) {
    return _companies[id].balances[account];
  }

  function _dividendsOf(bytes32 id, address account) private view returns (uint256) {
    return _companies[id].dividends[account];
  }

  function _changeAccountPrivacy() private returns (bool) {
    return _isPrivateAccount[_msgSender()] = !_isPrivateAccount[_msgSender()];
  }

  function _accountPrivacyStatus() private view returns (bool) {
    return _isPrivateAccount[_msgSender()];
  }

  function _payFee(uint256 value, uint256 feeAmount) private {
    require(value >= feeAmount, "ProfitDivider: fee too small");
    if (value > 0) {
      _commission += value;
      emit ProfitUpdated(_commission);
    }
  }

  function _divideCommission() private {
    require(_commission >= _minCommissionToDivide, "ProfitDivider: not enough profit to divide");
    uint256 commission = _commission;
    _commission = 0;
    _incomingCash(0x0, commission);
  }

  function _incomingCash(bytes32 id, uint256 value) private {
    (uint256 profitPerShare, uint256 remainder) = _profitPerShare(value, _companies[id].totalShares);
    _commission += remainder; // Остаток от деления прибыли идёт в комиссионные
    address[] memory holders = _companies[id].holders;
    for (uint8 i = 0; i < holders.length; ) {
      _companies[id].dividends[holders[i]] += _companies[id].balances[holders[i]] * profitPerShare;
      // prettier-ignore
      unchecked { i++; }
    }
    _companies[id].totalProfit += value;
    _companies[id].accumulatedProfit += value;
    _companies[id].latestIncomingCash = value;
    _companies[id].latestIncomingCashDate = block.timestamp;
    emit IncomingCash(id, value);
  }

  function _profitPerShare(uint256 totalProfit, uint256 totalShares) private pure returns (uint256, uint256) {
    uint256 remainder = totalProfit % totalShares;
    uint256 divisibleProfit = totalProfit - remainder;
    return (divisibleProfit / totalShares, remainder);
  }

  function _setRenameCompanyFee(uint256 value) private {
    _renameCompanyFee = value;
  }

  function _setMinProfitToDivide(uint256 value) private {
    _minCommissionToDivide = value;
  }

  function _setWithdrawCommission(uint16 value) private {
    require(value <= _withdrawCommissionMaxPart, "ProfitDivider: too large withdrawCommission");
    _withdrawCommissionParts = value;
    emit WithdrawCommissionChanged(value);
  }

  function _changeContacts(bytes32 id, string memory newContacts) private {
    string memory oldContacts = _companies[id].contacts;
    _companies[id].contacts = newContacts;
    emit CompanyContactsChanged(oldContacts, newContacts);
  }

  function _renameCompany(
    bytes32 id,
    string memory newName,
    uint256 pay
  ) private {
    _payFee(pay, _renameCompanyFee);
    string memory oldName = _companies[id].name;
    _companies[id].name = newName;
    emit CompanyNameChanged(oldName, newName);
  }

  function _setInvitationFee(bytes32 id, uint256 value) private {
    _companies[id].invitationFee = value;
    emit InvitationFeeChanged(id, value);
  }

  function _setMaxHolders(bytes32 id, uint8 value) private {
    require(_companies[id].holders.length >= value, "ProfitDivider: value is less than existing holders");
    require(value <= 256, "ProfitDivider: too large value (max. 256)");
    _companies[id].maxHolders = value;
    emit MaxHoldersChanged(id, value);
  }

  function _addCompanyToAccountsList(bytes32 id, address account) private {
    _accountCompanyIdtoIndex[account][id] = _accountCompanyIds[account].length;
    _accountCompanyIds[account].push(id);
    emit AddedCompanyToAccountList(id, account);
  }

  function _removeCompanyFromAccountsList(bytes32 id, address account) private {
    uint256 index = _accountCompanyIdtoIndex[account][id];
    delete _accountCompanyIdtoIndex[account][id];
    _accountCompanyIds[account][index] = _accountCompanyIds[account][_accountCompanyIds[account].length - 1];
    _accountCompanyIds[account].pop();
    emit RemovedCompanyToAccountList(id, account);
  }

  function _transfer(
    bytes32 id,
    address from,
    address to,
    uint256 value,
    uint256 pay
  ) private {
    require(from != address(0), "ProfitDivider: transfer from the zero address");
    require(to != address(0), "ProfitDivider: transfer to the zero address");
    require(!(_companies[id].balances[to] == 0 && _isPrivateAccount[to]), "ProfitDivider: recipient's account closed");

    _beforeTokenTransfer(id, from, to, value, pay);

    uint256 fromBalance = _companies[id].balances[from];
    require(fromBalance >= value, "ProfitDivider: transfer value exceeds balance");
    unchecked {
      _companies[id].balances[from] -= value;
      // Overflow not possible: the sum of all balances is capped by totalShares and the sum is preserved by
      // decrementing then incrementing.
      _companies[id].balances[to] += value;
    }

    emit Transfer(id, from, to, value);

    _afterTokenTransfer(id, from, to, value);
  }

  /**
   *  @dev
   *  external calling function must be nonReentrant
   *  openzeppelin/contracts/security/ReentrancyGuard.sol
   */
  function _withdrawTotalDividends() private {
    uint256 value = _myTotalDividends();
    uint256 commission = _calculateCommission(value);

    _checkContractBalance(value);

    (bool success, ) = _msgSender().call{value: value}("");
    require(success, "ProfitDivider: error when trying to withdraw dividends.");

    _totalProfit[_msgSender()] += value;
    _payFee(commission, commission);

    bytes32[] memory my_company_ids = _myCompanyIds();

    for (uint256 i; i < my_company_ids.length; ) {
      bytes32 id = my_company_ids[i];
      _companies[id].accumulatedProfit -= _companies[id].dividends[_msgSender()];
      _companies[id].dividends[_msgSender()] = 0;
      // prettier-ignore
      unchecked { i++; }
    }

    emit TotalDividendsWithdrawed(_msgSender(), value);
  }

  /**
   *  @dev
   *  external calling function must be nonReentrant
   *  openzeppelin/contracts/security/ReentrancyGuard.sol
   */
  function _withdrawAllDividends(bytes32 id) private {
    uint256 value = _dividendsOf(id, _msgSender());
    uint256 commission = _calculateCommission(value);
    _withdrawDividends(id, _msgSender(), _msgSender(), value - commission);
  }

  /**
   *  @dev
   *  external calling function must be nonReentrant
   *  openzeppelin/contracts/security/ReentrancyGuard.sol
   */
  function _withdrawDividends(
    bytes32 id,
    address from,
    address to,
    uint256 value
  ) private {
    uint256 commission = _calculateCommission(value);

    _checkContractBalance(value + commission);
    require(_dividendsOf(id, to) >= value + commission, "ProfitDivider: dividends balance is less than the requested value.");

    _companies[id].dividends[from] -= value + commission;
    (bool success, ) = to.call{value: value}("");
    if (!success) {
      _companies[id].dividends[_msgSender()] += value + commission;
    }
    require(success, "ProfitDivider: error when trying to withdraw dividends.");

    _payFee(commission, commission);
    _companies[id].accumulatedProfit -= value + commission;
    _totalProfit[_msgSender()] += value;
    emit DividendsWithdrawed(id, from, value);
  }

  function _calculateCommission(uint256 value) private view returns (uint256) {
    return ((value - (value % _commissionBaseParts)) / _commissionBaseParts) * _withdrawCommissionParts;
  }

  function _mint(
    bytes32 id,
    address account,
    uint256 value
  ) private {
    require(account != address(0), "ProfitDivider: mint to the zero address");

    _beforeTokenTransfer(id, address(0), account, value, 0);

    _companies[id].totalShares += value;
    unchecked {
      // Overflow not possible: balance + value is at most totalShares+ value, which is checked above.
      _companies[id].balances[account] += value;
    }
    emit Transfer(id, address(0), account, value);

    _afterTokenTransfer(id, address(0), account, value);
  }

  function _beforeTokenTransfer(
    bytes32 id,
    address, /*from*/
    address to,
    uint256, /*value*/
    uint256 pay
  ) private {
    if (_balanceOf(id, to) == 0) {
      require(_companies[id].holders.length < _companies[id].maxHolders, "ProfitDivider: no place for a new partner");
      _payFee(pay, _companies[id].invitationFee);
      _companies[id].addressToHolderId[to] = _companies[id].holders.length;
      _companies[id].holders.push(to);
      _addCompanyToAccountsList(id, to);
      emit HoldersAmountUpdated(id, _companies[id].holders.length);
    }
  }

  function _afterTokenTransfer(
    bytes32 id,
    address from,
    address, /*to*/
    uint256 /*value*/
  ) private {
    if (_balanceOf(id, from) == 0 && from != address(0)) {
      uint256 holder_id = _companies[id].addressToHolderId[from];
      delete _companies[id].addressToHolderId[from];
      _companies[id].holders[holder_id] = _companies[id].holders[_companies[id].holders.length - 1];
      _companies[id].holders.pop();
      if (from != _companies[id].owner) {
        _removeCompanyFromAccountsList(id, from);
      }
      _withdrawAllDividends(id);
      emit HoldersAmountUpdated(id, _companies[id].holders.length);
    }
  }

  function _checUri(string memory uri) private view returns (bool) {
    bytes memory byteStr = bytes(uri);
    if (
      // Нельзя короткие URI
      byteStr.length < _uriMinLength ||
      // Нельзя длинные URI
      byteStr.length > _uriMaxLength ||
      // Нельзя URI начинающиеся с '0x'
      (byteStr[0] == 0x30 && byteStr[1] == 0x78)
    ) {
      return false;
    }
    for (uint256 i = 0; i < byteStr.length; ) {
      // Проверка что символ из списка '0123456789abcdefghijklmnopqrstuvwxyz-_.'
      if (
        !((byteStr[i] >= 0x2d && byteStr[i] <= 0x2e) ||
          (byteStr[i] >= 0x30 && byteStr[i] <= 0x39) ||
          (byteStr[i] >= 0x61 && byteStr[i] <= 0x7a) ||
          byteStr[i] == 0x5f)
      ) {
        return false;
      }
      // prettier-ignore
      unchecked { i++; }
    }
    return true;
  }

  function _uriFee(uint256 uriLength) private view returns (uint256) {
    if (uriLength >= _freeUriLength || _uriMaxFee == 0) {
      return 0;
    }
    uint256 ratio = uriLength > _uriMinLength ? (uriLength - _uriMinLength + 1) * 2 : 1;
    return (_uriMaxFee - (_uriMaxFee % ratio)) / ratio;
  }
}
