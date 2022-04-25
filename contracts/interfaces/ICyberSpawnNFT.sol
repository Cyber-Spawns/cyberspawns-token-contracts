// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICyberSpawnNFT is IERC721 {
  function mint(address recipient, uint8 _spawnType, string memory metadataURI) external returns (uint256);
}
