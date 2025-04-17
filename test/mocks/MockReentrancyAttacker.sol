// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {FarcasterCrowdfund} from "../../src/FarcasterCrowdfund.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockReentrancyAttacker {
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
        if (attackInProgress) {
            attackInProgress = false; // Prevent infinite recursion
            crowdfund.claimFunds(targetCrowdfundId);
        }
    }
    
    receive() external payable {
        if (attackInProgress) {
            attackInProgress = false; // Prevent infinite recursion
            crowdfund.claimFunds(targetCrowdfundId);
        }
    }
}