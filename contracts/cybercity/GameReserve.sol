// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GameReserve {

  address public immutable cnd;
  address public immutable css;
  address public marketplace;

  constructor (address _cnd, address _css, address _marketplace) {
    require(_cnd != address(0), "zero address");
    require(_css != address(0), "zero address");
    require(_marketplace != address(0), "zero address");
    cnd = _cnd;
    css = _css;
    marketplace = _marketplace;
    IERC20(_cnd).approve(marketplace, type(uint256).max);
    IERC20(_css).approve(marketplace, type(uint256).max);
  }


}
