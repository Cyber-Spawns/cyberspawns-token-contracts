// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../../interfaces/ICyberSpawnAccessControl.sol";

contract CyberSpawn721 is ERC721URIStorage {

    using Counters for Counters.Counter;
    
    ICyberSpawnAccessControl accessControl;
    Counters.Counter private _tokenIds;
    uint256 private _totalTokens;
    bool private _paused;
    
    string public baseUri;
    mapping(uint256 => uint8) public spawnType;

    event Paused(address account);
    event Unpaused(address account);
    event AccessControlUpdated(address accessControl);

    modifier onlyAdmin() {
        require(accessControl.hasAdminRole(msg.sender), "not admin");
        _;
    }
    
    modifier onlySpawner() {
        require(accessControl.hasSpawnerRole(msg.sender), "not spawner");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "not paused");
        _;
    }

    constructor(ICyberSpawnAccessControl _accessControl) ERC721("Cyber Spawn", "CS") {
        require(address(_accessControl) != address(0), "Invalid Access Controls");
        accessControl = _accessControl;
    }
    
    function mint(address recipient, uint8 _spawnType, string memory metadataURI) external onlySpawner whenNotPaused returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        spawnType[newItemId] = _spawnType;
        _setTokenURI(newItemId, metadataURI);
        _mint(recipient, newItemId);
        return newItemId;
    }

    function setBaseUri(string memory _uri) external onlyAdmin {
        baseUri = _uri;
    }

    function pause() external onlyAdmin whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function unpause() external onlyAdmin whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    function updateAccessControl(ICyberSpawnAccessControl _accessControl) external onlyAdmin {
        require(address(_accessControl) != address(0), "zero address");
        accessControl = _accessControl;
        emit AccessControlUpdated(address(_accessControl));
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function baseTokenURI() external pure returns (string memory) {
        return "ipfs://";
    }

}