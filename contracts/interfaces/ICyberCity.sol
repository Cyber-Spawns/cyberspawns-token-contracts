// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICyberCity {
  function cyberSpawnNft() external view returns (address);
  function accessControl() external view returns (address);
  function feeAddress() external view returns (address);
  function css() external view returns (address);
  function cnd() external view returns (address);
  function currency() external view returns (address);
  function presale() external view returns (address);
  function marketplace() external view returns (address);
  function auction() external view returns (address);
}
