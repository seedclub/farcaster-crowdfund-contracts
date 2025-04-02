// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract FarcasterCrowdfundTest is Test {
    FarcasterCrowdfund public crowdfund;
    MockERC20 public usdc;
    
    address public contractDeployer = address(1);
    address public donor1 = address(2);
    address public donor2 = address(3);
    address public projectOwner = address(4);
    
    uint256 public constant INITIAL_BALANCE = 1000 * 10**6; // 1000 USDC (6 decimals)
    string public constant BASE_URI = "https://crowdfund.seedclub.com/nfts/";
    uint256 public constant MAX_DURATION = 7 days;
    uint256 public constant TEST_CONTENT_ID_1 = 1; // Example content ID
    uint256 public constant TEST_CONTENT_ID_2 = 2; // Example content ID
    uint256 public constant TEST_CONTENT_ID_3 = 3; // Example content ID
    uint256 public constant TEST_CONTENT_ID_4 = 4; // Example content ID
    uint256 public constant TEST_CONTENT_ID_5 = 5; // Example content ID
    uint256 public constant TEST_CONTENT_ID_6 = 6; // Example content ID
    uint256 public constant TEST_CONTENT_ID_7 = 7; // Example content ID
    uint256 public constant TEST_CONTENT_ID_8 = 8; // Example content ID
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);
        
        // Mint USDC to donors
        usdc.mint(donor1, INITIAL_BALANCE);
        usdc.mint(donor2, INITIAL_BALANCE);
        
        // Deploy the FarcasterCrowdfund contract
        vm.prank(contractDeployer);
        crowdfund = new FarcasterCrowdfund(
            address(usdc),
            contractDeployer,
            BASE_URI,
            MAX_DURATION
        );
    }
    
    function test_CreateCrowdfund() public {
        // Setup
        vm.prank(projectOwner);
        uint256 contentId = TEST_CONTENT_ID_1;

        // Create a crowdfund
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );

        // Assert
        (
            address cfOwner,
            uint256 goal,
            uint256 endTimestamp,
            uint256 totalRaised,
            bool fundsClaimed,
            bool cancelled,
            uint256 cfContentId
        ) = getCrowdfundDetails(crowdfundId);

        assertEq(cfOwner, projectOwner);
        assertEq(goal, 100 * 10**6);
        assertEq(endTimestamp, block.timestamp + 5 days);
        assertEq(totalRaised, 0);
        assertEq(fundsClaimed, false);
        assertEq(cancelled, false);
        assertEq(cfContentId, contentId);
    }
    
    function test_DonateAndMintNFT() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 contentId = TEST_CONTENT_ID_2;
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Approve USDC spending
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        
        // Debug: Check if donor is marked as donor before donation
        console.log("Before donation - isDonor:", crowdfund.isDonor(crowdfundId, donor1));
        
        // Donate to the crowdfund
        crowdfund.donate(crowdfundId, 50 * 10**6, contentId);
        vm.stopPrank();
        
        // Debug: Check if donor is marked as donor after donation
        console.log("After donation - isDonor:", crowdfund.isDonor(crowdfundId, donor1));
        
        // Check donation was recorded
        (,,,uint256 totalRaised,,, uint256 cfContentId) = getCrowdfundDetails(crowdfundId);
        assertEq(totalRaised, 50 * 10**6);
        assertEq(crowdfund.donations(crowdfundId, donor1), 50 * 10**6);
        assertEq(cfContentId, contentId);
        
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
        uint256 contentId = TEST_CONTENT_ID_3;
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // First donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 30 * 10**6);
        crowdfund.donate(crowdfundId, 30 * 10**6, contentId);
        uint256 firstTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        
        // Second donation from same donor
        usdc.approve(address(crowdfund), 20 * 10**6);
        crowdfund.donate(crowdfundId, 20 * 10**6, contentId);
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
        uint256 contentId = TEST_CONTENT_ID_4;
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Make donations to meet the goal
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 60 * 10**6);
        crowdfund.donate(crowdfundId, 60 * 10**6, contentId);
        vm.stopPrank();
        
        vm.startPrank(donor2);
        usdc.approve(address(crowdfund), 40 * 10**6);
        crowdfund.donate(crowdfundId, 40 * 10**6, contentId);
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
        (,,, uint256 totalRaisedAfterClaim, bool fundsClaimed,, uint256 cfContentId) = getCrowdfundDetails(crowdfundId);
        assertEq(totalRaisedAfterClaim, 100 * 10**6); // totalRaised should remain the same
        assertEq(fundsClaimed, true);
        assertEq(cfContentId, contentId);
    }
    
    function test_ClaimRefund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 contentId = TEST_CONTENT_ID_5;
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 50 * 10**6, contentId);
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
        // Verify totalRaised was updated
        (,,, uint256 totalRaisedAfterRefund,,, uint256 cfContentId) = getCrowdfundDetails(crowdfundId);
        assertEq(totalRaisedAfterRefund, 0);
        assertEq(cfContentId, contentId);
    }
    
    function test_CancelCrowdfund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint256 contentId = TEST_CONTENT_ID_6;
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 50 * 10**6, contentId);
        vm.stopPrank();
        
        // Cancel the crowdfund
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);
        
        // Verify crowdfund is cancelled
        (,,,,, bool cancelled, uint256 cfContentId) = getCrowdfundDetails(crowdfundId);
        assertEq(cancelled, true);
        assertEq(cfContentId, contentId);
        
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
            100 * 10**6, // 100 USDC
            MAX_DURATION + 1 days, // Exceeds max duration
            TEST_CONTENT_ID_7
        );
    }
    
    function test_PauseContract() public {
        // Pause the contract
        vm.prank(contractDeployer);
        crowdfund.setPaused(true);
        
        // Try to create a crowdfund
        vm.prank(projectOwner);
        vm.expectRevert("Contract is paused");
        crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            TEST_CONTENT_ID_8
        );
        
        // Unpause and verify it works
        vm.prank(contractDeployer);
        crowdfund.setPaused(false);
        
        vm.prank(projectOwner);
        uint256 contentId = 0;
        uint256 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        assertEq(crowdfundId, 0); // Should be the first crowdfund
        (,,,,,,uint256 cfContentId) = getCrowdfundDetails(crowdfundId);
        assertEq(cfContentId, contentId);
    }
    
    // Helper function to extract crowdfund details
    function getCrowdfundDetails(uint256 crowdfundId) internal view returns (
        address owner,
        uint256 goal,
        uint256 endTimestamp,
        uint256 totalRaised,
        bool fundsClaimed,
        bool cancelled,
        uint256 contentId
    ) {
        (owner, goal, endTimestamp, totalRaised, fundsClaimed, cancelled, contentId) = crowdfund.crowdfunds(crowdfundId);
    }
}
