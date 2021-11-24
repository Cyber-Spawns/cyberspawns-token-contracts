// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CyberSpawns721 is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public baseUri;

    constructor() ERC721("Cyber Spawns", "CS") {
   
    }


    function mint() public returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        return newItemId;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    function setBaseUri(string memory _uri) public onlyOwner {
        baseUri = _uri;
    }



}