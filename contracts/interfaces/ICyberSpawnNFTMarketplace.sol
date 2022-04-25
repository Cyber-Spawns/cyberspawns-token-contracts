// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface ICyberSpawnNFTMarketplace {
  function createOffer(uint256 tokenId, uint256 cssPrice, uint256 usdtPrice) external;
}
