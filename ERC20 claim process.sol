pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClaimableERC20 is ERC20, Ownable {
    // Total native coins (ETH) deposited for claims
    uint256 public totalClaimableETH;

    // Mapping to track claimed amounts per address
    mapping(address => bool) private _hasClaimed;

    // Event for claims
    event ETHClaimed(address indexed claimant, uint256 amount);

    // Constructor: Set up ERC20 with total supply 100, distribute balances, owner is E
    constructor(address A, address B, address C, address D, address E) 
        ERC20("ClaimableToken", "CLM") 
        Ownable(E)  // Owner is E
    {
        // Mint total supply 100
        _mint(address(this), 100);  // Temporarily mint to contract for distribution

        // Distribute balances
        _transfer(address(this), A, 20);
        _transfer(address(this), B, 15);
        _transfer(address(this), C, 35);
        _transfer(address(this), D, 30);
    }

    // Function to deposit ETH into the contract (only owner, for the 100 ETH)
    function depositETH() external payable onlyOwner {
        require(totalClaimableETH == 0, "ETH already deposited");
        require(msg.value == 100 ether, "Must deposit exactly 100 ETH");  // Assuming 100 ETH as per example
        totalClaimableETH = msg.value;
    }

    // Check if address is EOA (not contract)
    function isEOA(address account) public view returns (bool) {
        return account.code.length == 0;
    }

    // Claim function for token holders
    function claim() external {
        address claimant = msg.sender;
        require(balanceOf(claimant) > 0, "No tokens to claim with");
        require(!_hasClaimed[claimant], "Already claimed");
        require(isEOA(claimant), "Only EOAs (wallets) can claim; contracts cannot");

        // Calculate share: (balance / totalSupply) * totalClaimableETH
        uint256 share = (balanceOf(claimant) * totalClaimableETH) / totalSupply();

        // Mark as claimed
        _hasClaimed[claimant] = true;

        // Transfer ETH
        payable(claimant).transfer(share);

        emit ETHClaimed(claimant, share);

        // Reduce totalClaimableETH to reflect claimed amount
        totalClaimableETH -= share;
    }

    // Owner claims remaining ETH (including shares from contract addresses that couldn't claim)
    function ownerClaimRemaining() external onlyOwner {
        require(totalClaimableETH > 0, "No remaining ETH");
        uint256 remaining = totalClaimableETH;
        totalClaimableETH = 0;
        payable(owner()).transfer(remaining);
        emit ETHClaimed(owner(), remaining);
    }
}