// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenLock is Ownable {
  bool isLocked;

  event Freezed();
  event UnFreezed();

  modifier validLock {
    require(isLocked == false, "Token is locked");
    _;
  }

  function freeze() external onlyOwner {
    isLocked = true;

    emit Freezed();
  }

  function unfreeze() external onlyOwner {
    isLocked = false;

    emit UnFreezed();
  }
}
