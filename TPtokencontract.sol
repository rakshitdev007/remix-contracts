// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, ERC20Permit, Ownable {
    constructor(
        address initialOwner
    )
        ERC20("Trade Power", "TP")
        ERC20Permit("Trade Power")
        Ownable(initialOwner)
    {}

    /**
     * @dev Mint tokens to owner only
     */
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount * 10 ** decimals());
    }

    /**
     * @dev Burn tokens from any user account
     * Can only be called by owner
     */
    function burnFrom(address account, uint256 amount) external onlyOwner {
        _burn(account, amount * 10 ** decimals());
    }
}
