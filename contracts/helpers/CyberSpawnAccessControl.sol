// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract CyberSpawnAccessControl is AccessControl {
  /// @notice Role definitions
  bytes32 public constant GOVERNANCE_ROLE = 
    0x71840dc4906352362b0cdaf79870196c8e42acafade72d5d5a6d59291253ceb1;    // keccak256('GOVERNANCE_ROLE')
  bytes32 public constant SPAWNER_ROLE = 
    0x6cd0800d4f4ba3dc6faecb926dc1f046e4172cd4d0318c3b8740bdce16fe8d52;    // keccak256('SPAWNER_ROLE')
  bytes32 public constant GAME_ROLE = 
    0x6a64baf327d646d1bca72653e2a075d15fd6ac6d8cbd7f6ee03fc55875e0fa88;    // keccak256('GAME_ROLE')

  event AdminRoleGranted(address account);
  event AdminRoleRevoked(address account);
  event GoverenanceRoleGranted(address account);
  event GoverenanceRoleRevoked(address account);
  event SpawnerRoleGranted(address account);
  event SpawnerRoleRevoked(address account);
  event GameRoleGranted(address account);
  event GameRoleRevoked(address account);

  modifier onlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "not admin");
    _;
  }

  modifier onlyGovernance() {
    require(hasRole(GOVERNANCE_ROLE, msg.sender), "not governance");
    _;
  }

  modifier onlySpawner() {
    require(hasRole(SPAWNER_ROLE, msg.sender), "not spawner");
    _;
  }

  /**
   * @notice The deployer is automatically given the admin role which will allow them 
   *  to grant role to other addresses
   */
  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  //////////////////////////////////
  ////    External Functions    ////
  //////////////////////////////////

  function addAdminRole(address account) external onlyAdmin {
    grantRole(DEFAULT_ADMIN_ROLE, account);
    emit AdminRoleGranted(account);
  }

  function addGovernanceRole(address account) external onlyAdmin {
    grantRole(GOVERNANCE_ROLE, account);
    emit GoverenanceRoleGranted(account);
  }

  function addSpawnerRole(address account) external onlyAdmin {
    grantRole(SPAWNER_ROLE, account);
    emit SpawnerRoleGranted(account);
  }

  function addGameRole(address account) external onlyAdmin {
    grantRole(GAME_ROLE, account);
    emit GameRoleGranted(account);
  }

  function revokeAdminRole(address account) external onlyAdmin {
    revokeRole(DEFAULT_ADMIN_ROLE, account);
    emit AdminRoleRevoked(account);
  }

  function revokeGovernanceRole(address account) external onlyAdmin {
    revokeRole(GOVERNANCE_ROLE, account);
    emit GoverenanceRoleRevoked(account);
  }

  function revokeSpawnerRole(address account) external onlyAdmin {
    revokeRole(SPAWNER_ROLE, account);
    emit SpawnerRoleRevoked(account);
  }

  function revokeGameRole(address account) external onlyAdmin {
    revokeRole(GAME_ROLE, account);
    emit GameRoleRevoked(account);
  }

  //////////////////////////////
  ////    View Functions    ////
  //////////////////////////////

  function hasAdminRole(address account) external view returns (bool) {
    return hasRole(DEFAULT_ADMIN_ROLE, account);
  }

  function hasSpawnerRole(address account) external view returns (bool) {
    return hasRole(SPAWNER_ROLE, account);
  }

  function hasGovernanceRole(address account) external view returns (bool) {
    return hasRole(GOVERNANCE_ROLE, account);
  }

  function hasGameRole(address account) external view returns (bool) {
    return hasRole(GAME_ROLE, account);
  }
}
