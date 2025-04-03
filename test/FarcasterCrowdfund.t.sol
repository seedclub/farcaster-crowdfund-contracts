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
    
    uint128 public constant INITIAL_BALANCE = 1000 * 10**6; // 1000 USDC (6 decimals)
    string public constant BASE_URI = "https://crowdfund.seedclub.com/nfts/";
    uint64 public constant MAX_DURATION = 7 days;
    uint128 public constant TEST_CONTENT_ID_1 = 1; // Example content ID
    uint128 public constant TEST_CONTENT_ID_2 = 2; // Example content ID
    uint128 public constant TEST_CONTENT_ID_3 = 3; // Example content ID
    uint128 public constant TEST_CONTENT_ID_4 = 4; // Example content ID
    uint128 public constant TEST_CONTENT_ID_5 = 5; // Example content ID
    uint128 public constant TEST_CONTENT_ID_6 = 6; // Example content ID
    uint128 public constant TEST_CONTENT_ID_7 = 7; // Example content ID
    uint128 public constant TEST_CONTENT_ID_8 = 8; // Example content ID
    
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
        uint128 contentId = TEST_CONTENT_ID_1;

        // Create a crowdfund
        uint128 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );

        // Assert - Updated struct field order and types
        (
            uint128 goal,
            uint128 totalRaised,
            uint64 endTimestamp,
            uint128 cfContentId,
            address cfOwner,
            bool fundsClaimed,
            bool cancelled
        ) = crowdfund.crowdfunds(crowdfundId);

        assertEq(goal, 100 * 10**6);
        assertEq(totalRaised, 0);
        assertEq(endTimestamp, uint64(block.timestamp + 5 days));
        assertEq(cfContentId, contentId);
        assertEq(cfOwner, projectOwner);
        assertEq(fundsClaimed, false);
        assertEq(cancelled, false);
    }
    
    function test_DonateAndMintNFT() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_2;
        uint128 donationId = contentId; // Use contentId as donationId for testing
        uint128 crowdfundId = crowdfund.createCrowdfund(
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
        crowdfund.donate(crowdfundId, donationId, 50 * 10**6);
        vm.stopPrank();
        
        // Debug: Check if donor is marked as donor after donation
        console.log("After donation - isDonor:", crowdfund.isDonor(crowdfundId, donor1));
        
        // Check donation was recorded
        (, uint128 totalRaised, ,,,, ) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaised, 50 * 10**6);
        assertEq(crowdfund.donations(crowdfundId, donor1), 50 * 10**6);
        
        // Check NFT was minted
        uint128 tokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        console.log("Token ID:", tokenId);
        // First NFT should have token ID 0
        assertEq(tokenId, 0, "First NFT should have token ID 0");
        assertEq(crowdfund.ownerOf(tokenId), donor1);
        // Need to read the tokenToCrowdfund mapping with uint256 key as per definition
        assertEq(crowdfund.tokenToCrowdfund(uint256(tokenId)), crowdfundId); 
    }
    
    function test_MultipleDonations() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_3;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // First donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 30 * 10**6);
        crowdfund.donate(crowdfundId, 1, 30 * 10**6); // donationId 1
        uint128 firstTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        
        // Second donation from same donor
        usdc.approve(address(crowdfund), 20 * 10**6);
        crowdfund.donate(crowdfundId, 2, 20 * 10**6); // donationId 2
        uint128 secondTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        vm.stopPrank();
        
        // Check total donations
        assertEq(crowdfund.donations(crowdfundId, donor1), 50 * 10**6);
        
        // Verify only one NFT was minted (token IDs should be the same)
        assertEq(firstTokenId, secondTokenId);
    }
    
    function test_ClaimFunds() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_4;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Make donations to meet the goal
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 60 * 10**6);
        crowdfund.donate(crowdfundId, 1, 60 * 10**6); // donationId 1
        vm.stopPrank();
        
        vm.startPrank(donor2);
        usdc.approve(address(crowdfund), 40 * 10**6);
        crowdfund.donate(crowdfundId, 2, 40 * 10**6); // donationId 2
        vm.stopPrank();
        
        // Warp to after the end time
        vm.warp(block.timestamp + 6 days);
        
        // Record project owner's balance before claiming
        uint256 balanceBefore = usdc.balanceOf(projectOwner); // Balance is uint256
        
        // Claim funds
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);
        
        // Verify project owner received the funds
        uint256 balanceAfter = usdc.balanceOf(projectOwner); // Balance is uint256
        assertEq(balanceAfter - balanceBefore, uint256(100 * 10**6)); // Cast amount to uint256 for comparison
        
        // Verify crowdfund state
        (, uint128 totalRaisedAfterClaim, , , , bool fundsClaimed, bool cancelled) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaisedAfterClaim, 100 * 10**6); // totalRaised should remain the same
        assertEq(fundsClaimed, true);
        assertEq(cancelled, false); // Ensure it's not accidentally cancelled
    }
    
    function test_ClaimRefund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_5;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 1, 50 * 10**6); // donationId 1
        vm.stopPrank();
        
        // Warp to after the end time
        vm.warp(block.timestamp + 6 days);
        
        // Record donor's balance before claiming refund
        uint256 balanceBefore = usdc.balanceOf(donor1); // Balance is uint256
        
        // Claim refund
        vm.prank(donor1);
        crowdfund.claimRefund(crowdfundId);
        
        // Verify donor received the refund
        uint256 balanceAfter = usdc.balanceOf(donor1); // Balance is uint256
        assertEq(balanceAfter - balanceBefore, uint256(50 * 10**6)); // Cast amount to uint256 for comparison
        
        // Verify donation was reset
        assertEq(crowdfund.donations(crowdfundId, donor1), 0);
        // Verify totalRaised was updated
        (, uint128 totalRaisedAfterRefund, , , , , ) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaisedAfterRefund, 0);
    }
    
    function test_CancelCrowdfund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_6;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            100 * 10**6, // 100 USDC
            5 days,
            contentId
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 1, 50 * 10**6); // donationId 1
        vm.stopPrank();
        
        // Cancel the crowdfund
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);
        
        // Verify crowdfund is cancelled
        ( , , , , , , bool cancelled) = crowdfund.crowdfunds(crowdfundId);
        assertEq(cancelled, true);
    }

    // Additional tests for edge cases, modifiers, and access control

    function test_RevertWhen_DonateAfterEnd() public {
        // Setup
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_7;
        uint128 crowdfundId = crowdfund.createCrowdfund(100 * 10**6, 1 days, contentId);
        vm.warp(block.timestamp + 2 days); // Warp past end time

        // Attempt donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 10 * 10**6);
        vm.expectRevert("Crowdfund has ended");
        crowdfund.donate(crowdfundId, 1, 10 * 10**6);
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimFundsGoalNotMet() public {
        // Setup
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_8;
        uint128 crowdfundId = crowdfund.createCrowdfund(100 * 10**6, 5 days, contentId);
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 50 * 10**6);
        crowdfund.donate(crowdfundId, 1, 50 * 10**6);
        vm.stopPrank();
        vm.warp(block.timestamp + 6 days); // Warp past end time

        // Attempt claim
        vm.prank(projectOwner);
        vm.expectRevert("Goal not met");
        crowdfund.claimFunds(crowdfundId);
    }
    
    function test_RevertWhen_ClaimRefundGoalMet() public {
        // Setup - create a crowdfund and meet the goal
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_1; // Reusing content ID
        uint128 crowdfundId = crowdfund.createCrowdfund(100 * 10**6, 5 days, contentId);
        
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 100 * 10**6);
        crowdfund.donate(crowdfundId, 1, 100 * 10**6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 6 days); // Warp past end time

        // Attempt refund claim
        vm.prank(donor1);
        vm.expectRevert("Refunds not available - either goal met or crowdfund still active");
        crowdfund.claimRefund(crowdfundId);
    }

    function test_RevertWhen_CancelAfterClaim() public {
        // Setup - create, fund, and claim
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_2; // Reusing content ID
        uint128 crowdfundId = crowdfund.createCrowdfund(100 * 10**6, 5 days, contentId);
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 100 * 10**6);
        crowdfund.donate(crowdfundId, 1, 100 * 10**6);
        vm.stopPrank();
        vm.warp(block.timestamp + 6 days);
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);

        // Attempt cancel
        vm.expectRevert("Funds already claimed");
        // Prank as projectOwner to test the correct revert condition
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);
    }

    function test_GetDonors() public {
         // Setup
        vm.prank(projectOwner);
        uint128 contentId = TEST_CONTENT_ID_3; // Reusing
        uint128 crowdfundId = crowdfund.createCrowdfund(100 * 10**6, 5 days, contentId);

        // Donations
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 10 * 10**6);
        crowdfund.donate(crowdfundId, 1, 10 * 10**6);
        vm.stopPrank();

        vm.startPrank(donor2);
        usdc.approve(address(crowdfund), 20 * 10**6);
        crowdfund.donate(crowdfundId, 2, 20 * 10**6);
        vm.stopPrank();

        // Get donors
        address[] memory donors = crowdfund.getDonors(crowdfundId);

        // Assert
        assertEq(donors.length, 2);
        assertEq(donors[0], donor1);
        assertEq(donors[1], donor2);
    }

    // Helper function removed as direct struct access is now used
}
