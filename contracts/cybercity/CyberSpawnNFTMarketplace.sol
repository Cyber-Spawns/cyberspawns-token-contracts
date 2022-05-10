// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../helpers/CyberSpawnAccessControl.sol";
import "../interfaces/IUniswapV2Router.sol";

/**
 * @notice Marketplace contract for Cyber Spawn NFTs
 */
contract CyberSpawnNFTMarketplace is Context, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /// @notice Parameters of a marketplace offer
    struct Offer {
        uint256 price;
        uint256 startTime;
        uint256 endTime;
    }

    uint256 constant public MAX_BPS = 10_000;
    uint256 constant public LIVE_PERIOD = 7 * 24 * 3600;         // 7 days

    address public constant uniswapRouter = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    /// @notice Cyber Spawn NFT Token ID -> Offer Parameters
    mapping(uint256 => Offer) public offers;
    /// @notice Cyber Spawn NFT - the only NFT that can be offered in this contract
    IERC721 immutable public CyberSpawnNFT;
    IERC20 immutable public css;
    IERC20 immutable public currency;
    /// @notice responsible for enforcing admin access
    CyberSpawnAccessControl public accessControl;
    /// @notice platform fee amount
    uint256 public platformFee = 100e18;
    /// @notice where to send platform fee funds to
    address public platformFeeRecipient;
    /// @notice platform fee discount rate
    uint256 public discount = 5_000;
    /// @notice for pausing marketplace functionalities
    bool public isPaused;
    /// @notice path to swap USDT token to CSS
    address[] public path;

    /// @notice Event emitted only on construction. To be used by indexers
    event NFTMarketplaceContractDeployed();
    event PauseToggled(bool isPaused);
    event OfferCreated(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 price
    );
    event UpdateAccessControls(address indexed accessControl);
    event UpdateMarketplacePlatformFee(uint256 platformFee);
    event UpdateOfferSalePrice(uint256 indexed tokenId, uint256 price);
    event UpdatePlatformFeeRecipient(address platformFeeRecipient);
    event OfferPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        address paymentToken,
        uint256 paymentAmount,
        uint256 feeAmount
    );
    event OfferCancelled(uint256 indexed tokenId);
    event UpdateDiscountRate(uint256 discount);

    modifier whenNotPaused() {
        require(!isPaused, "Function is currently paused");
        _;
    }

    modifier onlyAdmin() {
        require(accessControl.hasAdminRole(_msgSender()), "NFTMarketplace.toggleIsPaused: Sender must be admin");
        _;
    }
    

    constructor(
        CyberSpawnAccessControl _accessControl,
        IERC721 _cyberSpawnNFT,
        IERC20 _currency,
        IERC20 _css,
        address[] memory _path,
        address _platformFeeRecipient
    ) {
        require(address(_accessControl) != address(0), "NFTMarketplace: Invalid Access Controls");
        require(address(_cyberSpawnNFT) != address(0), "NFTMarketplace: Invalid NFT");
        require(address(_css) != address(0), "NFTMarketplace: Invalid token address");
        require(_platformFeeRecipient != address(0), "NFTMarketplace: Invalid Platform Fee Recipient");
        accessControl = _accessControl;
        CyberSpawnNFT = _cyberSpawnNFT;
        currency = _currency;
        css = _css;
        path = _path;
        platformFeeRecipient = _platformFeeRecipient;

        emit NFTMarketplaceContractDeployed();
    }
    
    /**
     @notice Creates a new offer for a given Cyber Spawn NFT
     @dev Only the owner of a NFT can create an offer and must have ALREADY approved the contract
     @dev There cannot be a duplicate offer created
     @param _tokenId token ID of the NFT being offered to marketplace
     @param _usdtPrice NFT cannot be sold for less than this
     */
    function createOffer(
        uint256 _tokenId,
        uint256 _usdtPrice
    ) external whenNotPaused {
        // Check owner of the token ID is the owner and approved
        require(
            CyberSpawnNFT.ownerOf(_tokenId) == _msgSender() && CyberSpawnNFT.isApprovedForAll(_msgSender(), address(this)),
            "CyberSpawnNFTMarketplace.createOffer: Not owner and/or contract not approved"
        );
        require(_usdtPrice > 0, "invalid price");
        _createOffer(
            _tokenId,
            _usdtPrice,
            block.timestamp,
            block.timestamp + LIVE_PERIOD
        );
    }
    /**
     @notice Buys an open offer
     @dev Only callable when the offer is open
     @dev Bids from smart contracts are prohibited - a user must buy directly from their address
     @dev Contract must have been approved on the buy offer previously
     @dev The sale must have started (start time) to make a successful buy
     @dev The sale must be before end time
     @param _tokenId token ID of the NFT being offered
     */
    function confirmOffer(uint256 _tokenId, address paymentToken) external nonReentrant whenNotPaused {
        // Check the offers to see if this is a valid
        require(_msgSender() == tx.origin, "NFTMarketplace.confirmOffer: No contracts permitted");

        Offer storage offer = offers[_tokenId];
        
        require(_getNow() >= offer.startTime && _getNow() <= offer.endTime, "NFTMarketplace.confirmOffer: Purchase outside of the offer window");

        uint256 payAmount;
        uint256 fee;
        if (paymentToken == address(css)) {
            payAmount = _priceCss(offer.price);
            fee = platformFee.mul(discount).div(MAX_BPS);
        } else if (paymentToken == address(currency)) {
            payAmount = offer.price;
            fee = platformFee;
        } else {
            require(false, "invalid currency");
        }
        IERC20(paymentToken).safeTransferFrom(_msgSender(), CyberSpawnNFT.ownerOf(_tokenId), payAmount);
        css.safeTransferFrom(_msgSender(), platformFeeRecipient, fee);

        // Transfer the token to the purchaser
        CyberSpawnNFT.safeTransferFrom(CyberSpawnNFT.ownerOf(_tokenId), _msgSender(), _tokenId);
        
        //Remove offer
        delete offers[_tokenId];
        emit OfferPurchased(_tokenId, _msgSender(), paymentToken, payAmount, fee);
    }
    /**
     @notice Cancels an inflight and un-resulted offer
     @dev Only owner
     @param _tokenId Token ID of the NFT being offered
     */
    function cancelOffer(uint256 _tokenId) external nonReentrant {
        // Check owner of the token ID is the owner and approved
        require(
            CyberSpawnNFT.ownerOf(_tokenId) == _msgSender(),
            "CyberSpawnNFTMarketplace.cancelOffer: Not owner and or contract not approved"
        );
        // Check valid and not resulted
        Offer storage offer = offers[_tokenId];
        require(offer.price != 0, "NFTMarketplace.cancelOffer: Offer does not exist");
        require(_getNow() <= offer.endTime, "NFTMarketplace.cancelOffer: Offer already closed");
        // Remove offer
        delete offers[_tokenId];
        emit OfferCancelled(_tokenId);
    }

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external onlyAdmin {
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice set the uniswap router path for swapping css to currency token
     @dev Only admin
     @param _path address array for path
     */
    function setPath(address[] memory _path) external onlyAdmin {
        path = _path;
    }

    /**
     @notice set discount rate of tax
     @dev discount rate applies only when buying nft using css token as a payment token
     @param _rate discount rate value
     */
    function setDiscountRate(uint256 _rate) external onlyAdmin {
        require(_rate > 0, "invalid discount rate value");
        discount = _rate;
        emit UpdateDiscountRate(_rate);
    }

    /**
     @notice Update the marketplace fee
     @dev Only admin
     @param _platformFee New marketplace fee
     */
    function updateMarketplacePlatformFee(uint256 _platformFee) external onlyAdmin {
        platformFee = _platformFee;
        emit UpdateMarketplacePlatformFee(_platformFee);
    }

    /**
     @notice Update the offer sale price
     @dev Only admin
     @param _tokenId Token ID of the NFT being offered
     @param _salePrice New price
     */
    function updateOfferSalePrice(uint256 _tokenId, uint256 _salePrice) external onlyAdmin {
        
        offers[_tokenId].price = _salePrice;
        emit UpdateOfferSalePrice(_tokenId, _salePrice);
    }

    /**
     @notice Method for updating the access controls contract used by the NFT
     @dev Only admin
     @param _accessControl Address of the new access controls contract (Cannot be zero address)
     */
    function updateAccessControls(CyberSpawnAccessControl _accessControl) external onlyAdmin {
        require(address(_accessControl) != address(0), "NFTMarketplace.updateAccessControls: Zero Address");
        accessControl = _accessControl;
        emit UpdateAccessControls(address(_accessControl));
    }

    /**
     @notice Method for updating platform fee address
     @dev Only admin
     @param _platformFeeRecipient address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address _platformFeeRecipient) external onlyAdmin {
        require(_platformFeeRecipient != address(0), "NFTMarketplace.updatePlatformFeeRecipient: Zero address");
        platformFeeRecipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    ///////////////
    // Accessors //
    ///////////////
    /**
     @notice Method for getting all info about the offer
     @param _tokenId Token ID of the NFT being offered
     */
    function getOffer(uint256 _tokenId)
    external
    view
    returns (uint256 _usdtPrice, uint256 _startTime, uint256 _endTime) {
        Offer storage offer = offers[_tokenId];
        return (
            offer.price,
            offer.startTime,
            offer.endTime
        );
    }

    function priceCss(uint256 input) external view returns (uint256 output) {
        return _priceCss(input);
    }


    /////////////////////////
    // Internal and Private /
    /////////////////////////
    function _getNow() internal view returns (uint256) {
        return block.timestamp;
    }

    function _priceCss(uint256 input) internal view returns (uint256 output) {
        uint256[] memory amounts = IUniswapV2Router02(uniswapRouter).getAmountsOut(input, path);
        output = amounts[amounts.length - 1];
    }

    /**
     @notice Private method doing the heavy lifting of creating an offer
     @param _tokenId token ID of the NFT being offered to marketplace
     @param _usdtPrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function _createOffer(
        uint256 _tokenId,
        uint256 _usdtPrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) private {
        // Ensure a token cannot be re-listed if previously successfully sold
        require(offers[_tokenId].startTime == 0, "NFTMarketplace.createOffer: Cannot duplicate current offer");
        // Setup the new offer
        offers[_tokenId] = Offer({
            price: _usdtPrice,
            startTime : _startTimestamp,
            endTime : _endTimestamp
        });
        emit OfferCreated(_tokenId, CyberSpawnNFT.ownerOf(_tokenId), _usdtPrice);
    }
}
