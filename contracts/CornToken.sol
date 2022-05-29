// SPDX-License-Identifier: unlicensed

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CornToken is ERC20, Ownable {
    mapping (address => bool) internal authorizations;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _wallet
    ) ERC20 (_name, _symbol) {
        authorizations[_msgSender()] = true;
        _mint(_wallet, _totalSupply * (10 ** decimals()));
    }

    function mint(address _to, uint256 _amount) external {
        require(isAuthorized(msg.sender), "CornToken : UNAUTHORIZED");
        _mint(_to, _amount);
    }

    function authorize(address adr, bool _authorize) external onlyOwner {
        authorizations[adr] = _authorize;
    }

    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }
}