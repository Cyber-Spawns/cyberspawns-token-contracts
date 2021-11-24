// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;
import "./extensions/ERC20Pausable.sol";
import "./ERC20.sol";
import "./interfaces/IERC20.sol";

import "../helpers/SafeMath.sol";
import "./extensions/SafeERC20.sol";




contract Splinters is ERC20Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private _price;

    constructor( ) ERC20("Cyber Spawns Splinters", "CSS", 18, 200000000000000000000000000) {}



    function mint(uint256 amount) public virtual onlyOwner {
        address account = msg.sender;
        _mint(account, amount);
    }




    function withdrawTokens() public virtual onlyOwner{
        address contractAddress = address(this);
        uint tokenBalance = balanceOf(contractAddress);
        _transfer(contractAddress,owner,tokenBalance);
    }

    function price() public view returns (uint256) {
        return _price;
    }

    function SetPrice(uint256 priceInWei) public onlyOwner {
        _price = priceInWei;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(
            amount,
            "ERC20: burn amount exceeds allowance"
        );

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }

      function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdraw(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(_msgSender(), balance);        
    }

    
}
