// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ICyberSpawnAccessControl.sol";

interface ICyberSpawnNFT is IERC721 {
  function mint(address recipient, uint8 _spawnType, string memory metadataURI) external returns (uint256);
}

/**
 * @notice Presale contract for Cyber Spawn NFTs
 */

contract CyberSpawnPresale is ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  uint256 constant public TH = 20;                  // 100% / 5%
  uint256 constant public MAX_OWNABLE = 6;

  uint8 constant public CLASS_AVES = 0;
  uint8 constant public CLASS_MAMMALS = 1;
  uint8 constant public CLASS_REPTILES = 2;
  uint8 constant public CLASS_MOLLUSC = 3;
  uint8 constant public CLASS_AQUA = 4;

  ICyberSpawnNFT public cyberspawn;

  /// @notice payment token
  address public token = 0x55d398326f99059fF775485246999027B3197955;      // BSC USDT token

  ICyberSpawnAccessControl accessControl;
  /// @notice amount of on-sale cyberspawn
  uint256 public maxAmount = 920;
  string private metadataURI;
  
  /// @notice initial price of cyberspawn
  uint256 public initialPrice = 200 * 1e18;       // BSC USDT decimal is 18
  
  /// @notice price increase rate
  uint256 public rate = 50 * 1e18;                // BSC USDT decimal is 18

  uint256 totalRaised = 0;
  mapping (address => uint256) public contributions;

  mapping (uint8 => uint256) public sold;
  mapping (address => mapping (uint8 => uint256)) public spawns;

  /// @notice address to withdraw funds
  address public immutable wallet;

  /// @notice whitelisted address
  mapping (address => bool) public whitelist;
  uint256 public whiteAmount;

  /// @notice for pausing presale functionality and presale progress
  bool public isPaused;
  bool public onPresale;

  event PresaleContractDeployed();
  event CyberSpawnNFTPurchased(address recipient, uint256 aves, uint256 mammals, uint256 reptiles, uint256 mollusc, uint256 aqua, uint256 payAmount);
  event PresaleStarted(uint256 initialPrice, uint256 rate);
  event InitialPriceUpdated(uint256 oldVal, uint256 newVal);
  event RateUpdated(uint256 oldVal, uint256 newVal);
  event MetadataURIUpdated(string oldVal, string newVal);
  event MaxAmountUpdated(uint256 oldVal, uint256 newVal);
  event PresaleFinished(uint256 totalRaised, uint256 aves, uint256 mammals, uint256 reptiles, uint256 mollusc, uint256 aqua);

  modifier whenNotPaused() {
    require(!isPaused, "Fuction is currently paused");
    _;
  }

  modifier onlyAdmin() {
    require(accessControl.hasAdminRole(msg.sender), "not admin");
    _;
  }

  constructor(
    address _wallet, 
    ICyberSpawnNFT _nft, 
    string memory _metadataURI, 
    uint256 _whiteAmount, 
    ICyberSpawnAccessControl _accessControl
  ) {
    require(_wallet != address(0), "Presale: wallet is the zero address");
    require(address(_nft) != address(0), "Presale: NFT is zero address");
    require(address(_accessControl) != address(0), "Invalid Access Controls");

    wallet = _wallet;
    cyberspawn = _nft;
    metadataURI = _metadataURI;
    whiteAmount = _whiteAmount;
    accessControl = _accessControl;

    emit PresaleContractDeployed();
  }

  /**
   * @notice buy cyberspawn
   * @param recipient the address to receive NFTs
   * @param aves the amount of aves to purchase
   * @param mammals the amount of mammals to purchase
   * @param reptiles the amount of reptiles to purchase
   * @param mollusc the amount of mollusc to purchase
   * @param aqua the amount of aqua to purchase
   */
  function buySpawns(address recipient, uint256 aves, uint256 mammals, uint256 reptiles, uint256 mollusc, uint256 aqua) public nonReentrant whenNotPaused {
    require(recipient != address(0), "recipient is zero address");
    require(whitelist[recipient] || onPresale, "whitelist or can buy in presale peroid");
    
    // check if exceed one buy limit
    uint256 _amount = cyberspawn.balanceOf(recipient);
    require(_amount.add(aves).add(mammals).add(reptiles).add(mollusc).add(aqua) < MAX_OWNABLE, "exceed limit of ownable for one address");
    //whitelisted address can buy 
    uint256 buyAmount = aves.add(mammals).add(reptiles).add(mollusc).add(aqua);
    if (whitelist[recipient]) {
      whiteAmount = whiteAmount > buyAmount ? whiteAmount - buyAmount : 0;
    } else {
      uint256 totalSold = sold[CLASS_AVES].add(sold[CLASS_MAMMALS]).add(sold[CLASS_REPTILES]).add(sold[CLASS_MOLLUSC]).add(sold[CLASS_AQUA]);
      require(totalSold.add(buyAmount).add(whiteAmount) <= maxAmount.mul(5), "sold out");
    }

    uint256 payAmount = 0;
    if (aves > 0) {
      require(sold[CLASS_AVES].add(aves) <= maxAmount, "exceed balance");
      payAmount = _buySpawns(recipient, CLASS_AVES, aves);
    }

    if (mammals > 0) {
      require(sold[CLASS_MAMMALS].add(mammals) <= maxAmount, "exceed balance");
      payAmount = payAmount.add(_buySpawns(recipient, CLASS_MAMMALS, mammals));
    }

    if (reptiles > 0) {
      require(sold[CLASS_REPTILES].add(reptiles) <= maxAmount, "exceed balance");
      payAmount = payAmount.add(_buySpawns(recipient, CLASS_REPTILES, reptiles));
    }

    if (mollusc > 0) {
      require(sold[CLASS_MOLLUSC].add(mollusc) <= maxAmount, "exceed balance");
      payAmount = payAmount.add(_buySpawns(recipient, CLASS_MOLLUSC, mollusc));
    }

    if (aqua > 0) {
      require(sold[CLASS_AQUA].add(aqua) <= maxAmount, "exceed balance");
      payAmount = payAmount.add(_buySpawns(recipient, CLASS_AQUA, aqua));
    }

    IERC20(token).safeTransferFrom(msg.sender, address(this), payAmount);
    
    contributions[recipient] = contributions[recipient].add(payAmount);

    emit CyberSpawnNFTPurchased(recipient, aves, mammals, reptiles, mollusc, aqua, payAmount);
  }

  //////////////////////////
  ///   View Functions   ///
  //////////////////////////

  /**
   * @notice 
   *  return the current price of spawn.
   *  spawn price increases and its mechanisum is based on a bonding curve.
   * @param _spawnType spawn type value
   */
  function spawnPrice(uint8 _spawnType) external view returns (uint256) {
    uint256 bundle = maxAmount.div(TH);
    uint256 currentPrice = sold[_spawnType].div(bundle).mul(rate).add(initialPrice);
    return currentPrice;
  }

  function remainings() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
    uint256 totalSold = sold[CLASS_AVES].add(sold[CLASS_MAMMALS]).add(sold[CLASS_REPTILES]).add(sold[CLASS_MOLLUSC]).add(sold[CLASS_AQUA]);
    uint256 totalRemainings = maxAmount.mul(5).sub(totalSold);

    return (totalRemainings, whiteAmount, maxAmount.sub(sold[CLASS_AVES]), maxAmount.sub(sold[CLASS_MAMMALS]), maxAmount.sub(sold[CLASS_REPTILES]), maxAmount.sub(sold[CLASS_MOLLUSC]), maxAmount.sub(sold[CLASS_AQUA]));
  }

  /////////////////////////
  ///   Admin Actions   ///
  /////////////////////////

  /**
   * @notice Toggling the pause flag
   * @dev Only owner
   */
  function toggleIsPaused() external onlyAdmin {
      isPaused = !isPaused;
  }

  /**
   * @notice set the initial price of a NFT
   * @dev only owner
   * @param _price price value
   */
  function setInitialPrice(uint256 _price) external onlyAdmin {
    require(_price != 0, "price can't be zero");
    uint256 old = initialPrice;
    initialPrice = _price;

    emit InitialPriceUpdated(old, _price);
  }

  /**
   * @notice set price increasement rate
   * @dev only owner
   * @param _rate new rate
   */
  function setRate(uint256 _rate) external onlyAdmin {
    require(_rate != 0, "rate can't be zero");
    uint256 old = rate;
    rate = _rate;

    emit RateUpdated(old, _rate);
  }

  /**
   * @notice set max amount of cyberspawn to sell during presale
   * @dev only owner
   * @param _max max amount
   */
  function setMaxAmount(uint256 _max) external onlyAdmin {
    require(_max != 0, "can't be a zero");
    uint256 old = maxAmount;
    maxAmount = _max;

    emit MaxAmountUpdated(old, _max);
  }

  /**
   * @notice set the whitelisted address for presale
   * @dev only owner
   * @param _whitelist whitelisted address array
   */
  function setWhitelist(address[] memory _whitelist) external onlyAdmin {
    require(_whitelist.length != 0, "empty list");
    for (uint i = 0; i < _whitelist.length; i++) {
      require(_whitelist[i] != address(0), "!zero address");
      whitelist[_whitelist[i]] = true;
    }
  }

  function setMetadataURI(string memory _metadataURI) external onlyAdmin {
    emit MetadataURIUpdated(metadataURI, _metadataURI);
    metadataURI = _metadataURI;
  }

  /// @notice start presale
  function startPresale() external onlyAdmin {
    require(onPresale == false && totalRaised == 0, "invalid");
    onPresale = true;
    
    emit PresaleStarted(initialPrice, rate);
  }

  /// @notice stop presale
  /// @dev move fund to the admin wallet
  function stopPresale() external onlyAdmin {
    require(onPresale == true, "invalid");
    onPresale = false;
    _forwardFunds();

    emit PresaleFinished(totalRaised, sold[CLASS_AVES], sold[CLASS_MAMMALS], sold[CLASS_REPTILES], sold[CLASS_MOLLUSC], sold[CLASS_AQUA]);
  }

  //////////////////////////
  // Internal and Private //
  //////////////////////////

  function _buySpawns(address recipient, uint8 _spawnType, uint256 amount) internal returns (uint256) {
    uint256 payAmount = _spawnPrice(_spawnType, amount);
    for (uint i = 0; i < amount; i++) {
      cyberspawn.mint(recipient, _spawnType, metadataURI);
    }
    
    // Update state variables
    totalRaised = totalRaised.add(payAmount);
    spawns[recipient][_spawnType] = spawns[recipient][_spawnType].add(amount);
    sold[_spawnType] = sold[_spawnType].add(amount);

    return payAmount;
  }

  function _spawnPrice(uint8 _spawnType, uint256 amount) internal view returns (uint256) {
    uint256 bundle = maxAmount.div(TH);
    uint256 currentPrice = sold[_spawnType].div(bundle).mul(rate).add(initialPrice);           // currentPrice = initialPrice + (soldAmount / 230) * rate
    uint256 payAmount = currentPrice.mul(amount);
    uint256 firstTh = sold[_spawnType].div(bundle);
    uint256 lastTh = sold[_spawnType].add(amount).div(bundle);
    for (uint256 curTh = firstTh + 1; curTh <= lastTh; curTh++) {
      if(curTh != lastTh){
        payAmount = payAmount.add(rate.mul(curTh.sub(firstTh)).mul(bundle));
      } else {
        uint256 restAmount = sold[_spawnType].add(amount).mod(bundle);
        payAmount = payAmount.add(rate.mul(curTh.sub(firstTh)).mul(restAmount));
      }
    }

    return payAmount;
  }

  function _forwardFunds() internal {
    IERC20(token).safeTransfer(wallet, IERC20(token).balanceOf(address(this)));
  }

}