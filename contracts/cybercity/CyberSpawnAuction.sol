// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ICyberSpawnAccessControl.sol";
import "../interfaces/ICyberCity.sol";
import "../interfaces/ICyberSpawnNFTMarketplace.sol";

/**
 * @notice Primary sale auction contract for Cyber Spawn NFTs
 */
contract CyberSpawnNFTAuction is Context, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Parameters of an auction
    struct Auction {
        uint256 auctionId;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
    }

    /// @notice Information about the sender that placed a bit on an auction
    struct HighestBid {
        address bidder;
        uint256 bid;
        uint256 lastBidTime;
    }

    uint256 constant public MAX_BPS = 10_000;
    address immutable public cybercity;
    IERC20 immutable public currency;

    /// @notice NFT Token ID -> Auction Parameters
    mapping(uint256 => Auction) public auctions;

    /// @notice NFT Token ID -> highest bidder info (if a bid has been received)
    mapping(uint256 => HighestBid) public highestBids;

    /// @notice NFT - the only NFT that can be auctioned in this contract
    IERC721 public CyberSpawnNft;

    uint256 public counter;

    /// @notice globally and across all auctions, the amount by which a bid has to increase
    uint256 public minBidIncrement = 0.1 ether;

    /// @notice global platform fee, assumed to always be to 1 decimal place i.e. 200 = 2.0%
    uint256 public platformFee = 200;

    /// @notice for switching off auction creations, bids and withdrawals
    bool public isPaused;

    /// @notice Event emitted only on construction. To be used by indexers
    event NFTAuctionContractDeployed();

    event PauseToggled(
        bool isPaused
    );

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 reservePrice,
        uint256 startTimestamp,
        uint256 endTimestamp
    );

    event UpdateAuctionEndTime(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 endTime
    );

    event UpdateAuctionStartTime(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 startTime
    );

    event UpdateAuctionReservePrice(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 reservePrice
    );

    event UpdateAccessControls(
        address indexed accessControl
    );

    event UpdatePlatformFee(
        uint256 platformFee
    );

    event UpdatePlatformFeeRecipient(
        address platformFeeRecipient
    );

    event UpdateMinBidIncrement(
        uint256 minBidIncrement
    );

    event BidPlaced(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 bid
    );

    event AuctionResulted(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(
        uint256 indexed auctionId,
        uint256 indexed tokenId
    );

    modifier whenNotPaused() {
        require(!isPaused, "Function is currently paused");
        _;
    }

    modifier onlyAdmin {
        require(ICyberSpawnAccessControl(ICyberCity(cybercity).accessControl()).hasAdminRole(_msgSender()), "not admin");
        _;
    }

    constructor(address _cybercity) {
        require(_cybercity != address(0), "NFTAuction: Invalid CyberCity");

        cybercity = _cybercity;
        CyberSpawnNft = IERC721(ICyberCity(_cybercity).cyberSpawnNft());
        currency = IERC20(ICyberCity(_cybercity).currency());
        
        emit NFTAuctionContractDeployed();
    }

    /**
     @notice Creates a new auction for a given NFT
     @dev Only the owner of a NFT can create an auction and must have approved the contract
     @dev In addition to owning the NFT, the sender also has to have the MINTER role.
     @dev End time for the auction must be in the future.
     @param _tokenId Token ID of the NFT being auctioned
     @param _reservePrice NFT cannot be sold for less than this or minBidIncrement, whichever is higher
     @param _startTimestamp Unix epoch in seconds for the auction start time
     @param _endTimestamp Unix epoch in seconds for the auction end time.
     */
    function createAuction(
        uint256 _tokenId,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) external whenNotPaused {

        // Check owner of the token is the creator and approved
        require(
            CyberSpawnNft.ownerOf(_tokenId) == _msgSender() && CyberSpawnNft.isApprovedForAll(_msgSender(), address(this)),
            "NFTAuction.createAuction: Not owner and or contract not approved"
        );
        
        address marketplace = ICyberCity(cybercity).marketplace();
        (uint256 offerId, , , ) = ICyberSpawnNFTMarketplace(marketplace).getOffer(_tokenId);
        require(offerId == 0, "already on sale on marketplace");

        _createAuction(
            _tokenId,
            _reservePrice,
            _startTimestamp,
            _endTimestamp
        );
    }


    /**
     @notice Places a new bid, out bidding the existing bidder if found and criteria is reached
     @dev Only callable when the auction is open
     @dev Bids from smart contracts are prohibited to prevent griefing with always reverting receiver
     @param _tokenId Token ID of the NFT being auctioned
     */
    function placeBid(uint256 _tokenId, uint256 _bidAmount) external nonReentrant whenNotPaused {
        require(_msgSender() == tx.origin, "NFTAuction.placeBid: No contracts permitted");

        // Check the auction to see if this is a valid bid
        Auction storage auction = auctions[_tokenId];

        // Ensure auction is in flight
        require(
            _getNow() >= auction.startTime && _getNow() <= auction.endTime,
            "NFTAuction.placeBid: Bidding outside of the auction window"
        );

        uint256 bidAmount = _bidAmount;

        // Ensure bid adheres to outbid increment and threshold
        HighestBid storage highestBid = highestBids[_tokenId];
        uint256 minBidRequired = highestBid.bid + minBidIncrement;
        require(bidAmount >= minBidRequired, "NFTAuction.placeBid: Failed to outbid highest bidder");
        currency.safeTransferFrom(_msgSender(), address(this), bidAmount);

        // Refund existing top bidder if found
        if (highestBid.bidder != address(0)) {
            currency.safeTransfer(highestBid.bidder, highestBid.bid);
        }
        
        // assign top bidder and bid time
        highestBid.bidder = _msgSender();
        highestBid.bid = bidAmount;
        highestBid.lastBidTime = _getNow();

        emit BidPlaced(auction.auctionId, _tokenId, _msgSender(), bidAmount);
    }

    /**
     @notice Results a finished auction
     @dev Only owner
     @dev Auction can only be resulted if there has been a bidder and reserve met.
     @dev If there have been no bids, the auction needs to be cancelled instead using `cancelAuction()`
     @param _tokenId Token ID of the NFT being auctioned
     */
    function resultAuction(uint256 _tokenId) external nonReentrant {
        
        // Check owner of the token is the creator and approved
        require(
            CyberSpawnNft.ownerOf(_tokenId) == _msgSender(),
            "NFTAuction.resultAuction: Not owner"
        );

        // Check the auction to see if it can be resulted
        Auction storage auction = auctions[_tokenId];
        
        // Check the auction real
        require(auction.endTime > 0, "NFTAuction.resultAuction: Auction does not exist");

        // Check the auction has ended
        require(_getNow() > auction.endTime, "NFTAuction.resultAuction: The auction has not ended");

        // Ensure this contract is approved to move the token
        require(CyberSpawnNft.isApprovedForAll(_msgSender(), address(this)), "NFTAuction.resultAuction: auction not approved");

        // Get info on who the highest bidder is
        HighestBid storage highestBid = highestBids[_tokenId];
        address winner = highestBid.bidder;
        uint256 winningBid = highestBid.bid;

        // Ensure auction not already resulted
        require(winningBid >= auction.reservePrice, "NFTAuction.resultAuction: reserve not reached");

        // Ensure there is a winner
        require(winner != address(0), "NFTAuction.resultAuction: no open bids");

        // Clean up the highest bid
        delete highestBids[_tokenId];


        // Work out platform fee from above reserve amount
        uint256 pFee = winningBid * platformFee / MAX_BPS;

        // Send platform fee
        currency.safeTransfer(ICyberCity(cybercity).feeAddress(), pFee);

        // Send remaining to creator
        currency.safeTransfer(CyberSpawnNft.ownerOf(_tokenId), winningBid - pFee);

        // Transfer the token to the winner
        CyberSpawnNft.safeTransferFrom(CyberSpawnNft.ownerOf(_tokenId), winner, _tokenId);

        emit AuctionResulted(auctions[_tokenId].auctionId, _tokenId, winner, winningBid);
        
        // Remove auction and top bidder
        delete auctions[_tokenId];
    }
    
    /**
     @notice Cancels and inflight and un-resulted auctions, returning the funds to the top bidder if found
     @dev Only owner
     @param _tokenId Token ID of the NFT being auctioned
     */
    function cancelAuction(uint256 _tokenId) external nonReentrant {
        // Check owner of the token is the creator and approved
        require(
            CyberSpawnNft.ownerOf(_tokenId) == _msgSender(),
            "NFTAuction.cancelAuction: Not owner"
        );

        // Check valid and not resulted
        Auction storage auction = auctions[_tokenId];

        // Check auction is real
        require(auction.endTime > 0, "NFTAuction.cancelAuction: Auction does not exist");

        // refund existing top bidder if found
        HighestBid storage highestBid = highestBids[_tokenId];
        if (highestBid.bidder != address(0)) {
            currency.safeTransfer(highestBid.bidder, highestBid.bid);

            // Clear up highest bid
            delete highestBids[_tokenId];
        }

        emit AuctionCancelled(auction.auctionId, _tokenId);
        
        // Remove auction and top bidder
        delete auctions[_tokenId];
    }

    /**
     @notice Update the current reserve price for an auction
     @dev Only owner
     @dev Auction must exist
     @param _tokenId Token ID of the NFT being auctioned
     @param _reservePrice New Ether reserve price (WEI value)
     */
    function updateAuctionReservePrice(uint256 _tokenId, uint256 _reservePrice) external {
        // Check owner of the token is the creator and approved
        require(
            CyberSpawnNft.ownerOf(_tokenId) == _msgSender(),
            "NFTAuction.updateAuctionReservePrice: Not owner"
        );

        require(
            auctions[_tokenId].endTime > 0,
            "NFTAuction.updateAuctionReservePrice: No Auction exists"
        );

        auctions[_tokenId].reservePrice = _reservePrice;
        emit UpdateAuctionReservePrice(auctions[_tokenId].auctionId, _tokenId, _reservePrice);
    }

    /**
     @notice Update the current start time for an auction
     @dev Only owner
     @dev Auction must exist
     @param _tokenId Token ID of the NFT being auctioned
     @param _startTime New start time (unix epoch in seconds)
     */
    function updateAuctionStartTime(uint256 _tokenId, uint256 _startTime) external {
        require(_startTime > 0, "start time can not be zero");
        // Check owner of the token is the creator and approved
        require(
            CyberSpawnNft.ownerOf(_tokenId) == _msgSender(),
            "NFTAuction.updateAuctionStartTime: Not owner"
        );

        require(
            auctions[_tokenId].endTime > 0,
            "NFTAuction.updateAuctionStartTime: No Auction exists"
        );
        auctions[_tokenId].startTime = _startTime;
        emit UpdateAuctionStartTime(auctions[_tokenId].auctionId, _tokenId, _startTime);
    }

    /**
     @notice Update the current end time for an auction
     @dev Only owner
     @dev Auction must exist
     @param _tokenId Token ID of the NFT being auctioned
     @param _endTimestamp New end time (unix epoch in seconds)
     */
    function updateAuctionEndTime(uint256 _tokenId, uint256 _endTimestamp) external {
        // Check owner of the token is the creator and approved
        require(
            CyberSpawnNft.ownerOf(_tokenId) == _msgSender(),
            "NFTAuction.updateAuctionEndTime: Not owner"
        );
        require(
            auctions[_tokenId].endTime > 0,
            "NFTAuction.updateAuctionEndTime: No Auction exists"
        );
        require(
            auctions[_tokenId].startTime < _endTimestamp,
            "NFTAuction.updateAuctionEndTime: End time must be greater than start"
        );
        require(
            _endTimestamp > _getNow(),
            "NFTAuction.updateAuctionEndTime: End time passed. Nobody can bid"
        );

        auctions[_tokenId].endTime = _endTimestamp;
        emit UpdateAuctionEndTime(auctions[_tokenId].auctionId, _tokenId, _endTimestamp);
    }

    //////////
    // Admin /
    //////////

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external onlyAdmin {
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice Update the amount by which bids have to increase, across all auctions
     @dev Only admin
     @param _minBidIncrement New bid step in WEI
     */
    function updateMinBidIncrement(uint256 _minBidIncrement) external onlyAdmin {
        minBidIncrement = _minBidIncrement;
        emit UpdateMinBidIncrement(_minBidIncrement);
    }

    /**
     @notice Method for updating platform fee
     @dev Only admin
     @param _platformFee uint256 the platform fee to set
     */
    function updatePlatformFee(uint256 _platformFee) external onlyAdmin {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    ///////////////
    // Accessors //
    ///////////////

    /**
     @notice Method for getting all info about the auction
     @param _tokenId Token ID of the NFT being auctioned
     */
    function getAuction(uint256 _tokenId)
    external
    view
    returns (uint256 auctionId, uint256 _reservePrice, uint256 _startTime, uint256 _endTime) {
        Auction storage auction = auctions[_tokenId];
        return (
            auction.auctionId,
            auction.reservePrice,
            auction.startTime,
            auction.endTime
        );
    }

    /**
     @notice Method for getting all info about the highest bidder
     @param _tokenId Token ID of the NFT being auctioned
     */
    function getHighestBidder(uint256 _tokenId) external view returns (
        address _bidder,
        uint256 _bid,
        uint256 _lastBidTime
    ) {
        HighestBid storage highestBid = highestBids[_tokenId];
        return (
            highestBid.bidder,
            highestBid.bid,
            highestBid.lastBidTime
        );
    }

    /////////////////////////
    // Internal and Private /
    /////////////////////////
    
    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    /**
     @notice Private method doing the heavy lifting of creating an auction
     @param _tokenId Token ID of the NFT being auctioned
     @param _reservePrice NFT cannot be sold for less than this or minBidIncrement, whichever is higher
     @param _startTimestamp Unix epoch in seconds for the auction start time
     @param _endTimestamp Unix epoch in seconds for the auction end time.
     */
    function _createAuction(
        uint256 _tokenId,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) private {
        require(auctions[_tokenId].startTime == 0, "NFTAuction.createAuction: Cannot relist");

        // Check end time not before start time and that end is in the future
        require(_endTimestamp > _startTimestamp, "NFTAuction.createAuction: End time must be greater than start");
        require(_endTimestamp > _getNow(), "NFTAuction.createAuction: End time passed. Nobody can bid.");

        // Setup the auction
        counter++;
        auctions[_tokenId] = Auction({
            auctionId: counter,
            reservePrice : _reservePrice,
            startTime : _startTimestamp,
            endTime : _endTimestamp
        });

        emit AuctionCreated(counter, _tokenId, _reservePrice, _startTimestamp, _endTimestamp);
    }
}
