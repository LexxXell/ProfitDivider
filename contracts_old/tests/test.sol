// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract TestProfitDivider {

    function deposit() external payable {}

    function sendTo(address payable _to, uint256 value) external returns (bool){
        require(address(this).balance >= value, "Too large value");
        (bool success, ) = _to.call{value: value}("");
        return success;
    }
}