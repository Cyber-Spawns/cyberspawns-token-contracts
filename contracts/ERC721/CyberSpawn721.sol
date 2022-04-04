// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../helpers/CyberSpawnPausable.sol";

contract CyberSpawn721 is ERC721URIStorage, CyberSpawnPausable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 private _totalTokens;
    
    string public baseUri;
    mapping(uint256 => uint8) public spawnType;

    constructor() ERC721("Cyber Spawn", "CS") {}
    
    function mint(address recipient, uint8 _spawnType, string memory metadataURI) external onlySpawner returns (uint256) {
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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function baseTokenURI() external pure returns (string memory) {
        return "ipfs://";
    }

}