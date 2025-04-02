// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract FarcasterCrowdfundTest is Test {
    FarcasterCrowdfund public crowdfund;
    MockERC20 public usdc;
    
    address public owner = address(1);
    address public donor1 = address(2);
    address public donor2 = address(3);
    address public projectOwner = address(4);
    
    uint256 public constant INITIAL_BALANCE = 1000 * 10**6; // 1000 USDC (6 decimals)
    string public constant BASE_URI = "https://crowdfund.seedclub.com/nfts/";
    uint256 public constant MAX_DURATION = 7 days;
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);
        
        // Mint USDC to donors
        usdc.mint(donor1, INITIAL_BALANCE);
        usdc.mint(donor2, INITIAL_BALANCE);
        
        // Deploy the FarcasterCrowdfund contract
        vm.prank(owner);
        crowdfund = new FarcasterCrowdfund(
            address(usdc),
            owner,
            BASE_URI,
            MAX_DURATION
        );
    }
    
    function test_CreateCrowdfund() public {
        // Setup
        vm.prank(projectOwner);
        
        // Create a crowdfund
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // Assert
        (
            address cfOwner,
            uint256 goal,
            uint256 endTimestamp,
            uint256 totalRaised,
            bool fundsClaimed,
            bool cancelled,
            uint256 fid
        ) = getCrowdfundDetails(crowdfundId);
        
        assertEq(cfOwner, projectOwner);
        assertEq(goal, 100 * 10**6);
        assertEq(endTimestamp, block.timestamp + 5 days);
        assertEq(totalRaised, 0);
        assertEq(fundsClaimed, false);
        assertEq(cancelled, false);
        assertEq(fid, 12345);
    }
    
    function test_DonateAndMintNFT() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // Approve USDC spending
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        
        // Debug: Check if donor is marked as donor before donation
        console.log("Before donation - isDonor:", crowdfund.isDonor(crowdfundId, donor1));
        
        // Donate to the crowdfund
        crowdfund.donate(crowdfundId, 50 * 10**6, "Let's make this happen!");
        vm.stopPrank();
        
        // Debug: Check if donor is marked as donor after donation
        console.log("After donation - isDonor:", crowdfund.isDonor(crowdfundId, donor1));
        
        // Check donation was recorded
        (,,,uint256 totalRaised,,,) = getCrowdfundDetails(crowdfundId);
        assertEq(totalRaised, 50 * 10**6);
        assertEq(crowdfund.donations(crowdfundId, donor1), 50 * 10**6);
        
        // Check NFT was minted
        uint256 tokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        console.log("Token ID:", tokenId);
        // First NFT should have token ID 0
        assertEq(tokenId, 0, "First NFT should have token ID 0");
        assertEq(crowdfund.ownerOf(tokenId), donor1);
        assertEq(crowdfund.tokenToCrowdfund(tokenId), crowdfundId);
    }
    
    function test_MultipleDonations() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // First donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 30 * 10**6);
        crowdfund.donate(crowdfundId, 30 * 10**6, "First donation");
        uint256 firstTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        
        // Second donation from same donor
        usdc.approve(address(crowdfund), 20 * 10**6);
        crowdfund.donate(crowdfundId, 20 * 10**6, "Second donation");
        uint256 secondTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        vm.stopPrank();
        
        // Check total donations
        assertEq(crowdfund.donations(crowdfundId, donor1), 50 * 10**6);
        
        // Verify only one NFT was minted (token IDs should be the same)
        assertEq(firstTokenId, secondTokenId);
    }
    
    function test_ClaimFunds() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // Make donations to meet the goal
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 60 * 10**6);
        crowdfund.donate(crowdfundId, 60 * 10**6, "Big donation");
        vm.stopPrank();
        
        vm.startPrank(donor2);
        usdc.approve(address(crowdfund), 40 * 10**6);
        crowdfund.donate(crowdfundId, 40 * 10**6, "Completing the goal");
        vm.stopPrank();
        
        // Warp to after the end time
        vm.warp(block.timestamp + 6 days);
        
        // Record project owner's balance before claiming
        uint256 balanceBefore = usdc.balanceOf(projectOwner);
        
        // Claim funds
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);
        
        // Verify project owner received the funds
        uint256 balanceAfter = usdc.balanceOf(projectOwner);
        assertEq(balanceAfter - balanceBefore, 100 * 10**6);
        
        // Verify crowdfund state
        (,,, uint256 totalRaised, bool fundsClaimed,,) = getCrowdfundDetails(crowdfundId);
        assertEq(totalRaised, 100 * 10**6);
        assertEq(fundsClaimed, true);
    }
    
    function test_ClaimRefund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 50 * 10**6, "Hope this works out");
        vm.stopPrank();
        
        // Warp to after the end time
        vm.warp(block.timestamp + 6 days);
        
        // Record donor's balance before claiming refund
        uint256 balanceBefore = usdc.balanceOf(donor1);
        
        // Claim refund
        vm.prank(donor1);
        crowdfund.claimRefund(crowdfundId);
        
        // Verify donor received the refund
        uint256 balanceAfter = usdc.balanceOf(donor1);
        assertEq(balanceAfter - balanceBefore, 50 * 10**6);
        
        // Verify donation was reset
        assertEq(crowdfund.donations(crowdfundId, donor1), 0);
    }
    
    function test_CancelCrowdfund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 50 * 10**6, "Hope this works out");
        vm.stopPrank();
        
        // Cancel the crowdfund
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);
        
        // Verify crowdfund is cancelled
        (,,,,, bool cancelled,) = getCrowdfundDetails(crowdfundId);
        assertEq(cancelled, true);
        
        // Donor should be able to claim refund
        uint256 balanceBefore = usdc.balanceOf(donor1);
        vm.prank(donor1);
        crowdfund.claimRefund(crowdfundId);
        uint256 balanceAfter = usdc.balanceOf(donor1);
        assertEq(balanceAfter - balanceBefore, 50 * 10**6);
    }
    
    function test_MaxDuration() public {
        // Try to create a crowdfund with too long duration
        vm.prank(projectOwner);
        vm.expectRevert("Duration exceeds maximum allowed");
        crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            MAX_DURATION + 1 days, // Exceeds max duration
            12345 // Farcaster ID
        );
    }
    
    function test_PauseContract() public {
        // Pause the contract
        vm.prank(owner);
        crowdfund.setPaused(true);
        
        // Try to create a crowdfund
        vm.prank(projectOwner);
        vm.expectRevert("Contract is paused");
        crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        // Unpause and verify it works
        vm.prank(owner);
        crowdfund.setPaused(false);
        
        vm.prank(projectOwner);
        uint256 crowdfundId = crowdfund.createCrowdfund(
            "Fund a karaoke room",
            "Help us rent a karaoke room for Farcon 2025",
            100 * 10**6, // 100 USDC
            5 days,
            12345 // Farcaster ID
        );
        
        assertEq(crowdfundId, 0); // Should be the first crowdfund
    }
    
    // Helper function to extract crowdfund details
    function getCrowdfundDetails(uint256 crowdfundId) internal view returns (
        address owner,
        uint256 goal,
        uint256 endTimestamp,
        uint256 totalRaised,
        bool fundsClaimed,
        bool cancelled,
        uint256 fid
    ) {
        (owner, goal, endTimestamp, totalRaised, fundsClaimed, cancelled, fid) = crowdfund.crowdfunds(crowdfundId);
    }
}
