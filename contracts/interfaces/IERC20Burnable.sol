// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Burnable is IERC20 {
  function mint(address recipient, uint256 amount) external;
  function burn(address recipient, uint256 amount) external;
}
