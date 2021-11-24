// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract CyberSpawns721 is ERC721 {

    address public deployer;

    constructor() ERC721("Cyber Spawns", "CS") {
        deployer = msg.sender;
    }
}