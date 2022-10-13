// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CyberCoin is ERC20, Ownable {
  /**
   * @notice Constructor
   */
  constructor() ERC20("CyberCoin", "CC") { }

  function mint(address recipient, uint256 amount) external onlyOwner {
    require(recipient != address(0), "zero address");
    _mint(recipient, amount);
  }
}