// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {FarcasterCrowdfund} from "../../src/FarcasterCrowdfund.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "forge-std/console.sol";

contract MockReentrancyAttacker is IERC721Receiver {
    FarcasterCrowdfund public crowdfund;
    IERC20 public usdc;
    uint128 public targetCrowdfundId;
    bool public attackInProgress;
    
    constructor(address payable _crowdfund, address _usdc) {
        crowdfund = FarcasterCrowdfund(_crowdfund);
        usdc = IERC20(_usdc);
    }
    
    function setupAttack(uint128 _crowdfundId) external {
        targetCrowdfundId = _crowdfundId;
        attackInProgress = false;
        // Approve USDC for the crowdfund to use
        usdc.approve(address(crowdfund), type(uint256).max);
    }
    
    function executeAttack() external {
        attackInProgress = true;
        crowdfund.claimFunds(targetCrowdfundId);
    }
    
    // Fallback and receive functions that will trigger the reentrant call
    fallback() external payable {
        console.log("Attacker: fallback() triggered");
        if (attackInProgress) {
            attackInProgress = false; // Prevent infinite recursion
            // For claimFunds test (original logic):
             console.log("Attacker: Attempting reentrant claimFunds for CFID:", targetCrowdfundId);
             crowdfund.claimFunds(targetCrowdfundId); 
        }
    }
    
    receive() external payable {
        console.log("Attacker: receive() triggered");
        if (attackInProgress) {
            attackInProgress = false; // Prevent infinite recursion
            // For claimFunds test (original logic):
             console.log("Attacker: Attempting reentrant claimFunds for CFID:", targetCrowdfundId);
             crowdfund.claimFunds(targetCrowdfundId);
        }
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}