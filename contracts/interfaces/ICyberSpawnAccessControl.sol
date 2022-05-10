// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICyberSpawnAccessControl {
  function hasAdminRole(address account) external view returns (bool);
  function hasSpawnerRole(address account) external view returns (bool);
}
