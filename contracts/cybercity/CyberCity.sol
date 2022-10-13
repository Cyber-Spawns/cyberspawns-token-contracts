// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ICyberSpawnAccessControl.sol";

contract CyberCity {

  address immutable public cyberSpawnNft;
  address public accessControl;
  address public feeAddress;
  address public css;
  address public cnd;
  address public currency;
  address public presale;
  address public marketplace;
  address public auction;

  event AccessControlUpdated(address accessControl);
  event FeeAddressUpdated(address feeAddress);
  event PresaleAddressUpdated(address presale);
  event MarketplaceAddressUpdated(address marketplace);
  event AuctionAddressUpdated(address auction);

  modifier onlyAdmin() {
    require(ICyberSpawnAccessControl(accessControl).hasAdminRole(msg.sender), "not an admin");
    _;
  }

  constructor(
    address _cyberspawn,
    address _accessControl,
    address _feeAddress,
    address _css,
    address _cnd,
    address _currency
  ) {
    require(_cyberspawn != address(0), "!zero address");
    require(_accessControl != address(0), "!zero address");
    require(_feeAddress != address(0), "!zero address");
    require(_css != address(0), "!zero address");
    require(_cnd != address(0), "!zero address");
    require(_currency != address(0), "!zero address");
    cyberSpawnNft = _cyberspawn;
    accessControl = _accessControl;
    feeAddress = _feeAddress;
    css = _css;
    cnd = _cnd;
    currency = _currency;
  }

  /**
   @notice Method for updating the access controls contract used by the NFT
   @dev Only admin
   @param _accessControl Address of the new access controls contract (Cannot be zero address)
   */
  function updateAccessControls(address _accessControl) external onlyAdmin {
    require(_accessControl != address(0), "!zero address");
    accessControl = _accessControl;
    emit AccessControlUpdated(address(_accessControl));
  }

  function updateFeeAddress(address _feeAddress) external onlyAdmin {
    require(_feeAddress != address(0), "!zero address");
    feeAddress = _feeAddress;
    emit FeeAddressUpdated(_feeAddress);
  }

  function updatePresaleAddress(address _presale) external onlyAdmin {
    require(_presale != address(0), "!zero address");
    presale = _presale;
    emit PresaleAddressUpdated(_presale);
  }

  function updateMarketplaceAddress(address _marketplace) external onlyAdmin {
    require(_marketplace != address(0), "!zero address");
    marketplace = _marketplace;
    emit MarketplaceAddressUpdated(_marketplace);
  }

  function updateAuctionAddress(address _auction) external onlyAdmin {
    require(_auction != address(0), "!zero address");
    auction = _auction;
    emit AuctionAddressUpdated(_auction);
  }

}