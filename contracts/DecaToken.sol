// SPDX-License-Identifier: unlicensed

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DecaToken is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _wallet
    ) ERC20 (_name, _symbol) {
        _mint(_wallet, _totalSupply * (10 ** decimals()));
    }
}