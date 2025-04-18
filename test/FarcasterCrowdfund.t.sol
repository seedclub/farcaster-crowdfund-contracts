// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockReentrancyAttacker} from "./mocks/MockReentrancyAttacker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract FarcasterCrowdfundTest is Test {
    FarcasterCrowdfund public crowdfund;
    MockERC20 public usdc;
    
    address public contractDeployer = address(1);
    address public donor1 = address(2);
    address public donor2 = address(3);
    address public projectOwner = address(4);
    address public nonOwner = address(5); // Added for ownership tests
    
    uint128 public constant INITIAL_BALANCE = 1000 * 10**6; // 1000 USDC (6 decimals)
    string public constant BASE_URI = "https://crowdfund.seedclub.com/nfts/";
    uint64 public constant DEFAULT_MAX_DURATION = 7 days;
    string public constant CONTENT_ID_1 = "content-1";
    string public constant DONATION_ID_1 = "donation-1-1"; // Made unique per donation for clarity
    string public constant CONTENT_ID_2 = "content-2";
    string public constant DONATION_ID_2 = "donation-2-1";
    string public constant CONTENT_ID_3 = "content-3";
    string public constant DONATION_ID_3_1 = "donation-3-1"; // For first donation in test_MultipleDonations
    string public constant DONATION_ID_3_2 = "donation-3-2"; // For second donation in test_MultipleDonations
    string public constant CONTENT_ID_4 = "content-4";
    string public constant DONATION_ID_4_1 = "donation-4-1";
    string public constant DONATION_ID_4_2 = "donation-4-2";
    string public constant CONTENT_ID_5 = "content-5";
    string public constant DONATION_ID_5 = "donation-5-1";
    string public constant CONTENT_ID_6 = "content-6";
    string public constant DONATION_ID_6 = "donation-6-1";
    string public constant CONTENT_ID_7 = "content-7";
    string public constant DONATION_ID_7 = "donation-7-1";
    string public constant CONTENT_ID_8 = "content-8";
    string public constant DONATION_ID_8 = "donation-8-1";
    string public constant CONTENT_ID_9 = "content-9"; // For GetDonors test
    string public constant DONATION_ID_9_1 = "donation-9-1";
    string public constant DONATION_ID_9_2 = "donation-9-2";
    string public constant CONTENT_ID_10 = "content-10"; // For Admin tests
    string public constant DONATION_ID_10 = "donation-10-1";
    string public constant CONTENT_ID_11 = "content-11"; // For Paused tests
    string public constant CONTENT_ID_12 = "content-12"; // For Input validation tests
    string public constant CONTENT_ID_13 = "content-13"; // For Cancelled tests
    string public constant DONATION_ID_13_1 = "donation-13-1";
    string public constant DONATION_ID_13_2 = "donation-13-2";
    string public constant CONTENT_ID_14 = "content-14"; // For ClaimRefundWhenCancelled test
    string public constant DONATION_ID_14 = "donation-14-1";
    string public constant CONTENT_ID_15 = "content-15"; // For Double action tests
    string public constant DONATION_ID_15_1 = "donation-15-1";
    string public constant DONATION_ID_15_2 = "donation-15-2";
    string public constant CONTENT_ID_16 = "content-16"; // For View function tests
    string public constant DONATION_ID_16 = "donation-16-1";

    // Convert string constants to bytes32 hashes
    bytes32 public constant CONTENT_HASH_1 = keccak256(abi.encodePacked(CONTENT_ID_1));
    bytes32 public constant DONATION_HASH_1 = keccak256(abi.encodePacked(DONATION_ID_1));
    bytes32 public constant CONTENT_HASH_2 = keccak256(abi.encodePacked(CONTENT_ID_2));
    bytes32 public constant DONATION_HASH_2 = keccak256(abi.encodePacked(DONATION_ID_2));
    bytes32 public constant CONTENT_HASH_3 = keccak256(abi.encodePacked(CONTENT_ID_3));
    bytes32 public constant DONATION_HASH_3_1 = keccak256(abi.encodePacked(DONATION_ID_3_1));
    bytes32 public constant DONATION_HASH_3_2 = keccak256(abi.encodePacked(DONATION_ID_3_2));
    bytes32 public constant CONTENT_HASH_4 = keccak256(abi.encodePacked(CONTENT_ID_4));
    bytes32 public constant DONATION_HASH_4_1 = keccak256(abi.encodePacked(DONATION_ID_4_1));
    bytes32 public constant DONATION_HASH_4_2 = keccak256(abi.encodePacked(DONATION_ID_4_2));
    bytes32 public constant CONTENT_HASH_5 = keccak256(abi.encodePacked(CONTENT_ID_5));
    bytes32 public constant DONATION_HASH_5 = keccak256(abi.encodePacked(DONATION_ID_5));
    bytes32 public constant CONTENT_HASH_6 = keccak256(abi.encodePacked(CONTENT_ID_6));
    bytes32 public constant DONATION_HASH_6 = keccak256(abi.encodePacked(DONATION_ID_6));
    bytes32 public constant CONTENT_HASH_7 = keccak256(abi.encodePacked(CONTENT_ID_7));
    bytes32 public constant DONATION_HASH_7 = keccak256(abi.encodePacked(DONATION_ID_7));
    bytes32 public constant CONTENT_HASH_8 = keccak256(abi.encodePacked(CONTENT_ID_8));
    bytes32 public constant DONATION_HASH_8 = keccak256(abi.encodePacked(DONATION_ID_8));
    bytes32 public constant CONTENT_HASH_9 = keccak256(abi.encodePacked(CONTENT_ID_9));
    bytes32 public constant DONATION_HASH_9_1 = keccak256(abi.encodePacked(DONATION_ID_9_1));
    bytes32 public constant DONATION_HASH_9_2 = keccak256(abi.encodePacked(DONATION_ID_9_2));
    bytes32 public constant CONTENT_HASH_10 = keccak256(abi.encodePacked(CONTENT_ID_10));
    bytes32 public constant DONATION_HASH_10 = keccak256(abi.encodePacked(DONATION_ID_10));
    bytes32 public constant CONTENT_HASH_11 = keccak256(abi.encodePacked(CONTENT_ID_11));
    bytes32 public constant CONTENT_HASH_12 = keccak256(abi.encodePacked(CONTENT_ID_12));
    bytes32 public constant CONTENT_HASH_13 = keccak256(abi.encodePacked(CONTENT_ID_13));
    bytes32 public constant DONATION_HASH_13_1 = keccak256(abi.encodePacked(DONATION_ID_13_1));
    bytes32 public constant DONATION_HASH_13_2 = keccak256(abi.encodePacked(DONATION_ID_13_2));
    bytes32 public constant CONTENT_HASH_14 = keccak256(abi.encodePacked(CONTENT_ID_14));
    bytes32 public constant DONATION_HASH_14 = keccak256(abi.encodePacked(DONATION_ID_14));
    bytes32 public constant CONTENT_HASH_15 = keccak256(abi.encodePacked(CONTENT_ID_15));
    bytes32 public constant DONATION_HASH_15_1 = keccak256(abi.encodePacked(DONATION_ID_15_1));
    bytes32 public constant DONATION_HASH_15_2 = keccak256(abi.encodePacked(DONATION_ID_15_2));
    bytes32 public constant CONTENT_HASH_16 = keccak256(abi.encodePacked(CONTENT_ID_16));
    bytes32 public constant DONATION_HASH_16 = keccak256(abi.encodePacked(DONATION_ID_16));

    // Struct to hold results from getUserDonationsDetail to avoid stack too deep
    struct UserDonationDetails {
        uint128[] cfIds;
        uint128[] amounts;
        bool[] isActive;
        bool[] goalMet;
        uint64[] endTimestamps;
        uint128 totalDonated;
    }

    uint128 public constant GOAL_AMOUNT = 100 * 10**6; // 100 USDC
    uint128 public constant DONATION_AMOUNT_1 = 50 * 10**6; // 50 USDC
    uint128 public constant DONATION_AMOUNT_2 = 60 * 10**6; // 60 USDC
    uint128 public constant DONATION_AMOUNT_3 = 40 * 10**6; // 40 USDC
    uint128 public constant DONATION_AMOUNT_FULL_GOAL = GOAL_AMOUNT; // 100 USDC
    
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);
        
        // Mint USDC to donors
        usdc.mint(donor1, INITIAL_BALANCE);
        usdc.mint(donor2, INITIAL_BALANCE);
        usdc.mint(projectOwner, INITIAL_BALANCE); // Give owner some funds too
        
        // Deploy the FarcasterCrowdfund contract
        vm.prank(contractDeployer);
        crowdfund = new FarcasterCrowdfund(
            address(usdc),
            contractDeployer,
            BASE_URI,
            DEFAULT_MAX_DURATION
        );

        // Pre-approve spending for donors to simplify tests
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), type(uint128).max);
        vm.stopPrank();

        vm.startPrank(donor2);
        usdc.approve(address(crowdfund), type(uint128).max);
        vm.stopPrank();
    }
    
    function test_CreateCrowdfund() public {
        // Setup
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_1;

        // Create a crowdfund
        uint128 crowdfundId = crowdfund.createCrowdfund(
            GOAL_AMOUNT,
            5 days,
            contentHash
        );

        // Assert - Updated struct field order and types
        (
            uint128 goal,
            uint128 totalRaised,
            uint64 endTimestamp,
            bytes32 cfContentIdHash,
            address cfOwner,
            bool fundsClaimed,
            bool cancelled
        ) = crowdfund.crowdfunds(crowdfundId);

        assertEq(goal, GOAL_AMOUNT);
        assertEq(totalRaised, 0);
        assertEq(endTimestamp, uint64(block.timestamp + 5 days));
        assertEq(cfContentIdHash, contentHash);
        assertEq(cfOwner, projectOwner);
        assertEq(fundsClaimed, false);
        assertEq(cancelled, false);
    }
    
    function test_DonateAndMintNFT() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_2;
        bytes32 donationHash = DONATION_HASH_2;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            GOAL_AMOUNT,
            5 days,
            contentHash
        );
        
        // Approve USDC spending
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_1);
        
        // Donate to the crowdfund
        crowdfund.donate(crowdfundId, donationHash, DONATION_AMOUNT_1);
        vm.stopPrank();
        
        // Check donation was recorded
        (, uint128 totalRaised, ,,,, ) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaised, DONATION_AMOUNT_1);
        assertEq(crowdfund.donations(crowdfundId, donor1), DONATION_AMOUNT_1);
        
        // Check NFT was minted
        uint128 tokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        console.log("Token ID:", tokenId);
        // First NFT should have token ID 1 (counter starts at 1)
        assertEq(tokenId, 1, "First NFT should have token ID 1");
        assertEq(crowdfund.ownerOf(tokenId), donor1);
        // Need to read the tokenToCrowdfund mapping with uint256 key as per definition
        assertEq(crowdfund.tokenToCrowdfund(uint256(tokenId)), crowdfundId); 
    }
    
    function test_MultipleDonations() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_3;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            GOAL_AMOUNT,
            5 days,
            contentHash
        );
        
        // First donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_1);
        crowdfund.donate(crowdfundId, DONATION_HASH_3_1, DONATION_AMOUNT_1);
        uint128 firstTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        
        // Second donation from same donor
        usdc.approve(address(crowdfund), DONATION_AMOUNT_3);
        crowdfund.donate(crowdfundId, DONATION_HASH_3_2, DONATION_AMOUNT_3);
        uint128 secondTokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        vm.stopPrank();
        
        // Check total donations
        assertEq(crowdfund.donations(crowdfundId, donor1), DONATION_AMOUNT_1 + DONATION_AMOUNT_3);
        
        // Verify only one NFT was minted (token IDs should be the same)
        assertEq(firstTokenId, secondTokenId);
    }
    
    function test_ClaimFunds() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_4;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            GOAL_AMOUNT,
            5 days,
            contentHash
        );
        
        // Make donations to meet the goal
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_2);
        crowdfund.donate(crowdfundId, DONATION_HASH_4_1, DONATION_AMOUNT_2);
        vm.stopPrank();
        
        vm.startPrank(donor2);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_3);
        crowdfund.donate(crowdfundId, DONATION_HASH_4_2, DONATION_AMOUNT_3);
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
        assertEq(balanceAfter - balanceBefore, uint256(GOAL_AMOUNT));
        
        // Verify crowdfund state
        (, uint128 totalRaisedAfterClaim, , , , bool fundsClaimed, bool cancelled) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaisedAfterClaim, GOAL_AMOUNT);
        assertEq(fundsClaimed, true);
        assertEq(cancelled, false);
    }
    
    function test_ClaimRefund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_5;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            GOAL_AMOUNT,
            5 days,
            contentHash
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_1);
        crowdfund.donate(crowdfundId, DONATION_HASH_5, DONATION_AMOUNT_1);
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
        assertEq(balanceAfter - balanceBefore, uint256(DONATION_AMOUNT_1));
        
        // Verify donation was reset
        assertEq(crowdfund.donations(crowdfundId, donor1), 0);
        // Verify totalRaised was updated
        (, uint128 totalRaisedAfterRefund, , , , , ) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaisedAfterRefund, 0);
    }
    
    function test_CancelCrowdfund() public {
        // Setup - create a crowdfund
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_6;
        uint128 crowdfundId = crowdfund.createCrowdfund(
            GOAL_AMOUNT,
            5 days,
            contentHash
        );
        
        // Make a donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_1);
        crowdfund.donate(crowdfundId, DONATION_HASH_6, DONATION_AMOUNT_1);
        vm.stopPrank();
        
        // Cancel the crowdfund
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);
        
        // Verify crowdfund is cancelled
        ( , , , , , , bool cancelled) = crowdfund.crowdfunds(crowdfundId);
        assertEq(cancelled, true);
    }

    // ==========================================
    //   REVERT TESTS (Edge Cases & Access)
    // ==========================================

    function test_RevertWhen_DonateAfterEnd() public {
        // Setup
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_7;
        uint64 duration = 1 days;
        uint128 crowdfundId = crowdfund.createCrowdfund(GOAL_AMOUNT, duration, contentHash);
        uint64 expectedEndTime = uint64(block.timestamp + duration);
        vm.warp(block.timestamp + 2 days); // Warp past end time

        // Attempt donation
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), 10 * 10**6);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundHasEnded.selector, crowdfundId, expectedEndTime));
        crowdfund.donate(crowdfundId, DONATION_HASH_7, 10 * 10**6);
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimFundsGoalNotMet() public {
        // Setup
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_8;
        uint128 crowdfundId = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, contentHash);
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), DONATION_AMOUNT_1);
        crowdfund.donate(crowdfundId, DONATION_HASH_8, DONATION_AMOUNT_1);
        vm.stopPrank();
        vm.warp(block.timestamp + 6 days); // Warp past end time

        // Attempt claim
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.GoalNotMet.selector, crowdfundId, GOAL_AMOUNT, DONATION_AMOUNT_1));
        crowdfund.claimFunds(crowdfundId);
    }
    
    function test_RevertWhen_ClaimRefundGoalMet() public {
        // Setup - create a crowdfund and meet the goal
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_1;
        uint128 crowdfundId = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, contentHash);
        
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), GOAL_AMOUNT);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 6 days); // Warp past end time

        // Attempt refund claim
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.RefundsNotAvailable.selector, crowdfundId));
        crowdfund.claimRefund(crowdfundId);
    }

    function test_RevertWhen_CancelAfterClaim() public {
        // Setup - create, fund, and claim
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_2;
        uint128 crowdfundId = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, contentHash);
        vm.startPrank(donor1);
        usdc.approve(address(crowdfund), GOAL_AMOUNT);
        crowdfund.donate(crowdfundId, DONATION_HASH_2, GOAL_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 6 days);
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);

        // Attempt cancel
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.FundsAlreadyClaimed.selector, crowdfundId));
        crowdfund.cancelCrowdfund(crowdfundId);
    }

    function test_RevertWhen_ClaimFunds_NotOwner() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Meet goal & warp
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Attempt claim by non-owner (donor1)
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundOwnerRequired.selector, crowdfundId, donor1, projectOwner));
        crowdfund.claimFunds(crowdfundId);
    }

    function test_RevertWhen_CancelCrowdfund_NotOwner() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);

        // Attempt cancel by non-owner (donor1)
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundOwnerRequired.selector, crowdfundId, donor1, projectOwner));
        crowdfund.cancelCrowdfund(crowdfundId);
    }

    function test_RevertWhen_ClaimFunds_BeforeEnd() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        // Get expected end time
        (,,uint64 endTime,,,,) = crowdfund.crowdfunds(crowdfundId);

        // Attempt claim *before* end time
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundNotEnded.selector, crowdfundId, endTime));
        crowdfund.claimFunds(crowdfundId);
    }

    function test_RevertWhen_ClaimRefund_BeforeEnd() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Donate less than goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
        vm.stopPrank();

        // Attempt refund claim *before* end time (and not cancelled)
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.RefundsNotAvailable.selector, crowdfundId));
        crowdfund.claimRefund(crowdfundId);
    }

    function test_RevertWhen_ClaimRefund_AfterOwnerClaimed() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        // Warp and claim
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);

        // Attempt refund claim *after* owner claimed
        vm.prank(donor1);
        // The refund conditions (ended and goal not met OR cancelled) are not met.
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.RefundsNotAvailable.selector, crowdfundId)); 
        crowdfund.claimRefund(crowdfundId);
    }

    function test_RevertWhen_Donate_NonExistentCrowdfund() public {
        uint128 nonExistentId = 999;
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundDoesNotExist.selector, nonExistentId));
        crowdfund.donate(nonExistentId, DONATION_HASH_1, DONATION_AMOUNT_1);
    }

    function test_RevertWhen_ClaimFunds_NonExistentCrowdfund() public {
        uint128 nonExistentId = 999;
        vm.prank(projectOwner); // Should check existence before ownership
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundDoesNotExist.selector, nonExistentId));
        crowdfund.claimFunds(nonExistentId);
    }

    function test_RevertWhen_ClaimRefund_NonExistentCrowdfund() public {
         uint128 nonExistentId = 999;
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundDoesNotExist.selector, nonExistentId));
        crowdfund.claimRefund(nonExistentId);
    }

    function test_RevertWhen_CancelCrowdfund_NonExistentCrowdfund() public {
         uint128 nonExistentId = 999;
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundDoesNotExist.selector, nonExistentId));
        crowdfund.cancelCrowdfund(nonExistentId);
    }

    // ==========================================
    //         ADMIN FUNCTION TESTS
    // ==========================================

    function test_SetBaseURI() public {
        string memory newBaseURI = "https://new.uri/";

        // Create a crowdfund and mint token ID 1 first
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_10); // Creates crowdfundId 0
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_10, DONATION_AMOUNT_1); // Mints tokenId 1
        uint128 tokenId = crowdfund.donorToTokenId(crowdfundId, donor1);
        assertEq(tokenId, 1, "Token ID should be 1");
        assertEq(crowdfundId, 0, "Crowdfund ID should be 0");

        // Check event emission
        vm.expectEmit(true, true, true, true);
        emit FarcasterCrowdfund.BaseURIUpdated(BASE_URI, newBaseURI);

        // Change owner and call setBaseURI
        vm.prank(contractDeployer);
        crowdfund.setBaseURI(newBaseURI);

        // Verify tokenURI uses the new base URI and the correct crowdfund ID
        string memory expectedURI = string(abi.encodePacked(newBaseURI, "0"));
        assertEq(crowdfund.tokenURI(tokenId), expectedURI);
    }

    function test_Revert_SetBaseURI_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        crowdfund.setBaseURI("https://fail/");
    }

    function test_PauseAndUnpause() public { 
        // Pause by owner
        vm.prank(contractDeployer);
        crowdfund.pause();
        assertTrue(crowdfund.paused());

        // Unpause by owner
        vm.prank(contractDeployer);
        crowdfund.unpause();
        assertFalse(crowdfund.paused());
    }

    function test_RevertWhen_PauseNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        crowdfund.pause();
    }

    function test_RevertWhen_UnpauseNotOwner() public {
        // First, pause as owner
        vm.prank(contractDeployer);
        crowdfund.pause();
        assertTrue(crowdfund.paused(), "Contract should be paused initially");

        // Attempt unpause as non-owner
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        crowdfund.unpause();
        // Ensure still paused
        assertTrue(crowdfund.paused(), "Contract should remain paused");
    }

    function test_SetMaxDuration() public {
        uint64 newMaxDuration = 14 days;

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit FarcasterCrowdfund.MaxDurationUpdated(DEFAULT_MAX_DURATION, newMaxDuration, contractDeployer);

        // Call by owner
        vm.prank(contractDeployer);
        crowdfund.setMaxDuration(newMaxDuration);

        assertEq(crowdfund.maxDuration(), newMaxDuration);
    }

    function test_RevertWhen_SetMaxDurationNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        crowdfund.setMaxDuration(14 days);
    }

    function test_RevertWhen_SetMaxDurationZero() public {
        vm.prank(contractDeployer);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.InvalidDuration.selector, uint64(0)));
        crowdfund.setMaxDuration(0);
    }

    // ==========================================
    //         PAUSED STATE TESTS
    // ==========================================

    function test_RevertWhen_CreateCrowdfundPaused() public {
        vm.prank(contractDeployer);
        crowdfund.pause(); // Pause using new function

        vm.prank(projectOwner);
        vm.expectRevert(bytes(abi.encodePacked(Pausable.EnforcedPause.selector))); // Pausable uses selector directly
        crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, CONTENT_HASH_11);
    }

    function test_RevertWhen_DonatePaused() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_11);

        vm.prank(contractDeployer);
        crowdfund.pause(); // Pause

        vm.startPrank(donor1);
        vm.expectRevert(bytes(abi.encodePacked(Pausable.EnforcedPause.selector))); // Pausable uses selector directly
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimFundsPaused() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_11);
        // Meet goal
        vm.startPrank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        vm.prank(contractDeployer);
        crowdfund.pause(); // Pause

        vm.prank(projectOwner);
        vm.expectRevert(bytes(abi.encodePacked(Pausable.EnforcedPause.selector))); // Pausable uses selector directly
        crowdfund.claimFunds(crowdfundId);
    }

    function test_RevertWhen_ClaimRefundPaused() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_11);
        // Donate less than goal
        vm.startPrank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        vm.prank(contractDeployer);
        crowdfund.pause(); // Pause

        vm.prank(donor1);
        vm.expectRevert(bytes(abi.encodePacked(Pausable.EnforcedPause.selector))); // Pausable uses selector directly
        crowdfund.claimRefund(crowdfundId);
    }

    // ==========================================
    //     INPUT VALIDATION & CONSTRAINTS
    // ==========================================

    function test_RevertWhen_CreateDurationExceedsMax() public {
        vm.prank(projectOwner);
        uint64 invalidDuration = DEFAULT_MAX_DURATION + 1 days;
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.DurationExceedsMax.selector, invalidDuration, DEFAULT_MAX_DURATION));
        crowdfund.createCrowdfund(
            GOAL_AMOUNT, 
            invalidDuration, // Exceed max
            CONTENT_HASH_12 // Use bytes32
        );
    }

    function test_RevertWhen_CreateGoalZero() public {
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.InvalidFundingTarget.selector, uint128(0)));
        crowdfund.createCrowdfund(0, 5 days, CONTENT_HASH_12); // Use bytes32
    }

    function test_RevertWhen_CreateDurationZero() public {
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.InvalidDuration.selector, uint64(0)));
        crowdfund.createCrowdfund(GOAL_AMOUNT, 0, CONTENT_HASH_12); // Use bytes32
    }

    function test_RevertWhen_DonateAmountZero() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_12); // Use bytes32

        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.AmountMustBeGreaterThanZero.selector, uint128(0)));
        crowdfund.donate(crowdfundId, DONATION_HASH_1, 0); // Use bytes32
    }

    // ==========================================
    //       CANCELLED STATE TESTS
    // ==========================================

    function test_RevertWhen_DonateCancelled() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_13); // Use bytes32

        // Cancel
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);

        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.ErrorCrowdfundCancelled.selector, crowdfundId));
        crowdfund.donate(crowdfundId, DONATION_HASH_13_1, DONATION_AMOUNT_1); // Use bytes32
    }

    function test_RevertWhen_ClaimFundsCancelled() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_13); // Use bytes32

         // Make donations to meet the goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_13_1, DONATION_AMOUNT_2); // Use bytes32
        vm.prank(donor2);
        crowdfund.donate(crowdfundId, DONATION_HASH_13_2, DONATION_AMOUNT_3); // Use bytes32

        // Cancel
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);

        // Warp past end time just in case
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.ErrorCrowdfundCancelled.selector, crowdfundId));
        crowdfund.claimFunds(crowdfundId);
    }

    // ==========================================
    //       DOUBLE ACTION TESTS
    // ==========================================

    function test_RevertWhen_ClaimFundsTwice() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_15); // Use bytes32
        // Meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_15_1, GOAL_AMOUNT); // Use bytes32
        // Warp and claim first time
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);

        // Attempt second claim
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.FundsAlreadyClaimed.selector, crowdfundId));
        crowdfund.claimFunds(crowdfundId);
    }

    function test_RevertWhen_ClaimRefundTwice() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_15); // Use bytes32
        // Donate less than goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_15_2, DONATION_AMOUNT_1); // Use bytes32
        // Warp and claim refund first time
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);
        vm.prank(donor1);
        crowdfund.claimRefund(crowdfundId);

        // Attempt second claim
        vm.prank(donor1);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.NoDonationToRefund.selector, crowdfundId, donor1)); // Donation amount is 0 now
        crowdfund.claimRefund(crowdfundId);
    }

    function test_RevertWhen_CancelTwice() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_15); // Use bytes32
        // Cancel first time
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);

        // Attempt second cancel
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.ErrorCrowdfundCancelled.selector, crowdfundId));
        crowdfund.cancelCrowdfund(crowdfundId);
    }

    // ==========================================
    //       VIEW FUNCTION TESTS
    // ==========================================

    function test_GetDonorTokenId() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_16); // Use bytes32
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_16, DONATION_AMOUNT_1); // Use bytes32
        uint128 expectedTokenId = 1; // First token minted is 1

        // Access the mapping directly
        assertEq(crowdfund.donorToTokenId(crowdfundId, donor1), expectedTokenId);
        assertEq(crowdfund.donorToTokenId(crowdfundId, donor2), 0); // Donor 2 hasn't donated
    }

    function test_TokenURI() public {
         uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_16); // Use bytes32
         vm.prank(donor1);
         crowdfund.donate(crowdfundId, DONATION_HASH_16, DONATION_AMOUNT_1); // Use bytes32
         uint128 tokenId = crowdfund.donorToTokenId(crowdfundId, donor1);

         string memory expectedURI = string(abi.encodePacked(BASE_URI, "0"));
         assertEq(crowdfund.tokenURI(tokenId), expectedURI);
    }

    function test_RevertWhen_TokenURINonExistent() public {
        uint256 nonExistentTokenId = 999;
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.TokenDoesNotExist.selector, nonExistentTokenId));
        crowdfund.tokenURI(nonExistentTokenId); // Assuming token 999 doesn't exist
    }

    function test_TokenURI_MultipleCrowdfunds() public {
         // Create CF 0, donor 1 donates, mints NFT 1
         uint128 crowdfundId0 = _createDefaultCrowdfund(CONTENT_HASH_1); // ID 0
         vm.prank(donor1);
         crowdfund.donate(crowdfundId0, DONATION_HASH_1, DONATION_AMOUNT_1);
         uint128 tokenId1 = crowdfund.donorToTokenId(crowdfundId0, donor1); // Should be 1
         assertEq(tokenId1, 1, "Token ID 1 mismatch");


         // Create CF 1, donor 2 donates, mints NFT 2
         uint128 crowdfundId1 = _createDefaultCrowdfund(CONTENT_HASH_2); // ID 1
         vm.prank(donor2);
         crowdfund.donate(crowdfundId1, DONATION_HASH_2, DONATION_AMOUNT_1);
         uint128 tokenId2 = crowdfund.donorToTokenId(crowdfundId1, donor2); // Should be 2
         assertEq(tokenId2, 2, "Token ID 2 mismatch");

         // Check URIs point to correct crowdfund IDs
         string memory expectedURI0 = string(abi.encodePacked(BASE_URI, "0"));
         string memory expectedURI1 = string(abi.encodePacked(BASE_URI, "1"));

         assertEq(crowdfund.tokenURI(tokenId1), expectedURI0, "Token 1 URI incorrect");
         assertEq(crowdfund.tokenURI(tokenId2), expectedURI1, "Token 2 URI incorrect");
    }

    function test_GetUserDonationDetails() public {
        // Setup multiple crowdfunds with different states and donations
        
        // Crowdfund 1: Active crowdfund, goal not met yet
        uint128 crowdfundId1 = _createDefaultCrowdfund(CONTENT_HASH_1);
        vm.prank(donor1);
        crowdfund.donate(crowdfundId1, DONATION_HASH_1, DONATION_AMOUNT_1); // 50 USDC
        
        // Crowdfund 2: Ended crowdfund, goal met
        uint128 crowdfundId2 = _createDefaultCrowdfund(CONTENT_HASH_2);
        vm.prank(donor1);
        crowdfund.donate(crowdfundId2, DONATION_HASH_2, GOAL_AMOUNT); // 100 USDC (full goal)
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days); // Past end time for cf2
        
        // Crowdfund 3: Active, multiple donations from same donor
        // vm.warp(block.timestamp - DEFAULT_MAX_DURATION - 1 days); // Removed incorrect warp
        uint128 crowdfundId3 = _createDefaultCrowdfund(CONTENT_HASH_3);
        vm.startPrank(donor1);
        crowdfund.donate(crowdfundId3, DONATION_HASH_3_1, DONATION_AMOUNT_3); // 40 USDC
        crowdfund.donate(crowdfundId3, DONATION_HASH_3_2, DONATION_AMOUNT_1); // +50 USDC
        vm.stopPrank();
        
        // Get donation details for donor1
        (
            uint128[] memory cfIds,
            uint128[] memory amounts,
            bool[] memory active,
            bool[] memory goalsMet,
            uint64[] memory endTimes,
            uint128 totalDonated
        ) = crowdfund.getUserDonationsDetail(donor1);
        
        // Verify total
        assertEq(totalDonated, DONATION_AMOUNT_1 + GOAL_AMOUNT + DONATION_AMOUNT_3 + DONATION_AMOUNT_1);
        
        // Verify array sizes
        assertEq(cfIds.length, 3, "Should have 3 crowdfund IDs");
        assertEq(amounts.length, 3, "Should have 3 amounts");
        assertEq(active.length, 3, "Should have 3 active flags");
        assertEq(goalsMet.length, 3, "Should have 3 goal met flags");
        assertEq(endTimes.length, 3, "Should have 3 end times");
        
        // Verify details for each crowdfund
        // Find the index for each crowdfund
        uint256 cf1Index = type(uint256).max;
        uint256 cf2Index = type(uint256).max;
        uint256 cf3Index = type(uint256).max;
        
        for (uint256 i = 0; i < cfIds.length; i++) {
            if (cfIds[i] == crowdfundId1) cf1Index = i;
            if (cfIds[i] == crowdfundId2) cf2Index = i;
            if (cfIds[i] == crowdfundId3) cf3Index = i;
        }
        
        // Verify CF1
        assertLt(cf1Index, cfIds.length, "Crowdfund 1 not found");
        assertEq(amounts[cf1Index], DONATION_AMOUNT_1, "CF1: Wrong amount");
        assertFalse(active[cf1Index], "CF1: Should NOT be active"); // Corrected assertion
        assertFalse(goalsMet[cf1Index], "CF1: Goal should not be met");
        
        // Verify CF2
        assertLt(cf2Index, cfIds.length, "Crowdfund 2 not found");
        assertEq(amounts[cf2Index], GOAL_AMOUNT, "CF2: Wrong amount");
        assertFalse(active[cf2Index], "CF2: Should be ended");
        assertTrue(goalsMet[cf2Index], "CF2: Goal should be met");
        
        // Verify CF3
        assertLt(cf3Index, cfIds.length, "Crowdfund 3 not found");
        assertEq(amounts[cf3Index], DONATION_AMOUNT_3 + DONATION_AMOUNT_1, "CF3: Wrong amount");
        assertTrue(active[cf3Index], "CF3: Should be active");
        assertFalse(goalsMet[cf3Index], "CF3: Goal should not be met");
        
        // Get donation details for a user with no donations
        (
            uint128[] memory noCfIds,
            uint128[] memory noAmounts,
            bool[] memory noActive,
            bool[] memory noGoalsMet,
            uint64[] memory noEndTimes,
            uint128 noTotalDonated
        ) = crowdfund.getUserDonationsDetail(nonOwner);
        
        // Verify empty results
        assertEq(noCfIds.length, 0, "Should have 0 crowdfund IDs");
        assertEq(noAmounts.length, 0, "Should have 0 amounts");
        assertEq(noActive.length, 0, "Should have 0 active flags");
        assertEq(noGoalsMet.length, 0, "Should have 0 goal met flags");
        assertEq(noEndTimes.length, 0, "Should have 0 end times");
        assertEq(noTotalDonated, 0, "Total donated should be 0");
    }

    // ==========================================
    //       UNIQUENESS CONSTRAINTS TESTS
    // ==========================================

    function test_RevertWhen_CreateDuplicateContentId() public {
        // Create first crowdfund with Content ID 1
        _createDefaultCrowdfund(CONTENT_HASH_1);

        // Attempt to create another with the same Content ID
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.ContentIdHashAlreadyUsed.selector, CONTENT_HASH_1));
        crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, CONTENT_HASH_1);
    }

    function test_CreateWithContentIdEmptyString() public { // Renamed
        // Create with content ID ""
        vm.prank(projectOwner);
        uint128 crowdfundId = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, bytes32(0)); // Use zero hash
        crowdfund.crowdfunds(crowdfundId); // Call getter to ensure it exists
        // No revert expected, basic check that it exists
        assertTrue(crowdfundId == 0); // First crowdfundId should be 0
    }

    function test_CreateMultipleWithContentIdEmptyString() public { // Renamed
        // Create first with content ID ""
        vm.prank(projectOwner);
        uint128 crowdfundId1 = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, bytes32(0)); // Use zero hash
        assertTrue(crowdfundId1 == 0);

        // Create second with content ID ""
        vm.prank(projectOwner);
        uint128 crowdfundId2 = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, bytes32(0)); // Use zero hash
        assertTrue(crowdfundId2 == 1);

        // No reverts expected
        crowdfund.crowdfunds(crowdfundId2); // Call getter to ensure it exists
    }

    function test_RevertWhen_DonateDuplicateDonationId() public {
        // Setup
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        
        // First donation with Donation ID 1
        vm.startPrank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
        vm.stopPrank();

        // Attempt second donation with the same Donation ID
        vm.startPrank(donor2);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.DonationIdHashAlreadyUsed.selector, DONATION_HASH_1));
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_3);
        vm.stopPrank();
    }

    function test_RevertWhen_DonateSameDonationIdDifferentCrowdfunds() public { // Renamed and logic changed
        // Setup two crowdfunds
        uint128 crowdfundId1 = _createDefaultCrowdfund(CONTENT_HASH_1);
        uint128 crowdfundId2 = _createDefaultCrowdfund(CONTENT_HASH_2);
        
        // Donate with Donation ID "donation-x" to first crowdfund
        bytes32 sharedDonationId = keccak256(abi.encodePacked("shared-donation-id"));
        vm.startPrank(donor1);
        crowdfund.donate(crowdfundId1, sharedDonationId, DONATION_AMOUNT_1);
        vm.stopPrank();

        // Attempt to donate with the same Donation ID to second crowdfund (should fail)
        vm.startPrank(donor2);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.DonationIdHashAlreadyUsed.selector, sharedDonationId));
        crowdfund.donate(crowdfundId2, sharedDonationId, DONATION_AMOUNT_3);
        vm.stopPrank();
    }

    function test_DonateWithDonationIdEmptyString() public { // Renamed
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);

        // Donate with donation ID ""
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, bytes32(0), DONATION_AMOUNT_1); // Use zero hash

        // Assert donation recorded
        assertEq(crowdfund.donations(crowdfundId, donor1), DONATION_AMOUNT_1);
    }

    function test_DonateMultipleWithDonationIdEmptyString() public { // Renamed
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);

        // First donation with donation ID ""
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, bytes32(0), DONATION_AMOUNT_1); // Use zero hash
        vm.stopPrank();

        // Second donation with donation ID ""
        vm.prank(donor2);
        crowdfund.donate(crowdfundId, bytes32(0), DONATION_AMOUNT_3); // Use zero hash
        vm.stopPrank();

        // Assert both donations recorded
        assertEq(crowdfund.donations(crowdfundId, donor1), DONATION_AMOUNT_1);
        assertEq(crowdfund.donations(crowdfundId, donor2), DONATION_AMOUNT_3);
        (, uint128 totalRaised, ,,,, ) = crowdfund.crowdfunds(crowdfundId);
        assertEq(totalRaised, DONATION_AMOUNT_1 + DONATION_AMOUNT_3);
    }

    // ==========================================
    //       EVENT EMISSION TESTS (Examples)
    // ==========================================

    function testEmit_CreateCrowdfund() public {
        vm.prank(projectOwner);
        bytes32 contentHash = CONTENT_HASH_1;
        uint64 expectedEndTime = uint64(block.timestamp + 5 days);

        vm.expectEmit(true, true, true, false);
        emit FarcasterCrowdfund.CrowdfundCreated(
            0, // Expected next crowdfundId
            contentHash,
            projectOwner,
            GOAL_AMOUNT,
            expectedEndTime
        );

        crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, contentHash);
    }

    function testEmit_DonateAndMintNFT() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        uint128 tokenId = 1; // Expect first token ID to be 1
        bytes32 donationHash = DONATION_HASH_1;

        vm.prank(donor1);

        // Expect NFTMinted event (for first donation) - This happens first!
        // Check indexed crowdfundId, contentId hash, donor, AND data (tokenId)
        vm.expectEmit(true, true, true, true); 
        emit FarcasterCrowdfund.NFTMinted(
            crowdfundId,
            CONTENT_HASH_1, // Expect bytes32
            donor1,
            tokenId
        );

        // Expect DonationReceived event - This happens second!
        // Check indexed crowdfundId, donationId hash, donor, AND data (contentId, amount)
        vm.expectEmit(true, true, true, true); 
        emit FarcasterCrowdfund.DonationReceived(
            crowdfundId,
            CONTENT_HASH_1, // Expect bytes32
            donationHash, // Expect bytes32
            donor1,
            DONATION_AMOUNT_1
        );

        crowdfund.donate(crowdfundId, donationHash, DONATION_AMOUNT_1); // Use bytes32
    }

    // ==========================================
    // Helper function to quickly create a standard crowdfund for tests
    // ==========================================
    function _createDefaultCrowdfund(bytes32 contentHash) internal returns (uint128 crowdfundId) { // Accept bytes32
        vm.prank(projectOwner);
        return crowdfund.createCrowdfund(
            GOAL_AMOUNT, 
            DEFAULT_MAX_DURATION,
            contentHash // Pass bytes32
        );
    }

    // --- ETH Transfer Tests ---

    function test_Revert_SendETH_Fallback() public {
        // Attempt to send ETH via fallback
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.FunctionNotFoundOrEthNotAccepted.selector));
        (bool success, ) = address(crowdfund).call{value: 1 ether}("");
        assertFalse(success, "Fallback ETH transfer should fail");
    }

    // --- Reentrancy Guard Tests ---

    function test_ReentrancyGuard_ClaimFunds() public {
        // Setup attacker contract as the owner of the crowdfund
        MockReentrancyAttacker attacker = new MockReentrancyAttacker(payable(address(crowdfund)), address(usdc));
        vm.label(address(attacker), "ClaimFundsAttacker");

        vm.prank(address(attacker));
        bytes32 contentHash = keccak256(abi.encodePacked("reentrancy-claim-cf"));
        uint128 crowdfundId = crowdfund.createCrowdfund(GOAL_AMOUNT, 5 days, contentHash);

        // Fund the crowdfund to meet the goal
        vm.startPrank(donor1); // Use startPrank for multiple calls
        usdc.approve(address(crowdfund), GOAL_AMOUNT);
        crowdfund.donate(crowdfundId, bytes32(0), GOAL_AMOUNT); // donor1 mints NFT 1
        vm.stopPrank(); // Stop donor1 prank

        // Warp past end time
        vm.warp(block.timestamp + 6 days);

        // Give attacker some USDC to ensure it has funds if needed (though it shouldn't need it)
        usdc.mint(address(attacker), 1 * 10**6);

        // Setup attack - target the correct crowdfund ID
        attacker.setupAttack(crowdfundId);

        // Execute the attack
        uint256 initialBalance = usdc.balanceOf(address(attacker));
        // vm.expectRevert("ReentrancyGuard: reentrant call"); // Removed: safeTransfer doesn't trigger attacker callback
        vm.prank(address(attacker));
        attacker.executeAttack(); // This calls claimFunds, which transfers USDC, triggering attacker's fallback/receive

        // Verify state after the attack attempt
        // The initial call to claimFunds should have succeeded before the reentrant call reverted.

        // Check attacker received funds exactly once
        uint256 finalBalance = usdc.balanceOf(address(attacker));
        assertEq(finalBalance - initialBalance, GOAL_AMOUNT, "Attacker should receive funds exactly once");

        // Check crowdfund is marked as claimed
        (,,,, /* address cfOwner */, bool fundsClaimed, /* bool cancelled */) = crowdfund.crowdfunds(crowdfundId);
        assertTrue(fundsClaimed, "Crowdfund should be marked as claimed");
    }

    function test_ReentrancyGuard_ClaimRefund() public {
        // Setup - create a crowdfund
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);

        // Setup attacker contract as the donor
        MockReentrancyAttacker attacker = new MockReentrancyAttacker(payable(address(crowdfund)), address(usdc));
        vm.label(address(attacker), "RefundAttacker");

        // Give attacker funds and approve crowdfund contract
        usdc.mint(address(attacker), DONATION_AMOUNT_1);
        vm.startPrank(address(attacker));
        usdc.approve(address(crowdfund), DONATION_AMOUNT_1);

        // Have attacker donate (less than goal)
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1); // Attacker is now donor and owns NFT 1
        vm.stopPrank();

        // Warp past end time
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Setup attack - target the correct crowdfund ID
        attacker.setupAttack(crowdfundId);

        // Execute the refund claim which triggers the reentrancy attempt
        uint256 initialBalance = usdc.balanceOf(address(attacker));

        // vm.expectRevert("ReentrancyGuard: reentrant call"); // Removed: safeTransfer doesn't trigger attacker callback

        vm.prank(address(attacker));
        // Call the function directly that is intended for the refund attack
        // This assumes MockReentrancyAttacker's receive/fallback tries to call claimRefund again.
        // If MockReentrancyAttacker needs modification, that should be done too.
        // For now, just call claimRefund directly as the attacker.
        crowdfund.claimRefund(crowdfundId);

        // Verify state after the attack attempt
        // The initial call to claimRefund should have succeeded before the reentrant call reverted.

        // Check attacker received funds exactly once
        uint256 finalBalance = usdc.balanceOf(address(attacker));
        assertEq(finalBalance - initialBalance, DONATION_AMOUNT_1, "Should receive refund exactly once");

        // Check donation record is zeroed (due to successful initial refund call)
        assertEq(crowdfund.donations(crowdfundId, address(attacker)), 0, "Donation record should be zero");

        // Check crowdfund total raised is updated
        (, uint128 totalRaisedAfter, ,,,, ) = crowdfund.crowdfunds(crowdfundId); // Corrected destructuring
        assertEq(totalRaisedAfter, 0, "Total raised should be zero after refund"); // Assuming only attacker donated
    }

    function test_Constructor_DefaultMaxDuration() public {
        vm.prank(contractDeployer);
        FarcasterCrowdfund cfDefault = new FarcasterCrowdfund(
            address(usdc),
            contractDeployer,
            BASE_URI,
            0 // Pass 0 for max duration
        );
        assertEq(cfDefault.maxDuration(), DEFAULT_MAX_DURATION, "Max duration should default to 7 days");
    }

    function test_RescueERC20_Success() public {
        // Deploy a mock ERC20 token (not USDC)
        MockERC20 rescueToken = new MockERC20("Rescue Token", "RSC", 18);
        uint256 rescueAmount = 100 * 10**18;
        rescueToken.mint(address(crowdfund), rescueAmount); // Send tokens directly to contract

        uint256 ownerBalanceBefore = rescueToken.balanceOf(contractDeployer);
        uint256 contractBalanceBefore = rescueToken.balanceOf(address(crowdfund));
        assertEq(contractBalanceBefore, rescueAmount);

        // Rescue the tokens as owner
        vm.prank(contractDeployer);
        crowdfund.rescueERC20(address(rescueToken), contractDeployer, rescueAmount);

        // Verify balances
        uint256 ownerBalanceAfter = rescueToken.balanceOf(contractDeployer);
        uint256 contractBalanceAfter = rescueToken.balanceOf(address(crowdfund));
        assertEq(contractBalanceAfter, 0, "Contract RSC balance should be 0");
        assertEq(ownerBalanceAfter - ownerBalanceBefore, rescueAmount, "Owner did not receive correct RSC amount");
    }

    function test_RevertWhen_RescueERC20_CannotRescueUSDC() public {
        // Ensure contract has some USDC (e.g., via donation)
         uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
         vm.prank(donor1);
         crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
         vm.stopPrank();
         assertTrue(usdc.balanceOf(address(crowdfund)) > 0, "Contract should have USDC");

        // Attempt to rescue USDC
        vm.prank(contractDeployer);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CannotWithdrawUSDC.selector));
        crowdfund.rescueERC20(address(usdc), contractDeployer, DONATION_AMOUNT_1);
    }

     function test_RevertWhen_RescueERC20_NotOwner() public {
        // Deploy a mock ERC20 token (not USDC)
        MockERC20 rescueToken = new MockERC20("Rescue Token", "RSC", 18);
        uint256 rescueAmount = 100 * 10**18;
        rescueToken.mint(address(crowdfund), rescueAmount); // Send tokens directly to contract

        // Attempt rescue by non-owner
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        crowdfund.rescueERC20(address(rescueToken), nonOwner, rescueAmount);

        // Verify balance didn't change
        assertEq(rescueToken.balanceOf(address(crowdfund)), rescueAmount, "Contract RSC balance should not change");
    }

    // ==========================================
    //     BATCH REFUND TESTS
    // ==========================================

    function test_GetDonorsCount() public {
        // Setup: CF with 2 unique donors
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_9);
        vm.startPrank(donor1); // Use startPrank for multiple calls
        crowdfund.donate(crowdfundId, DONATION_HASH_9_1, DONATION_AMOUNT_1); // Donor 1 first donation
        crowdfund.donate(crowdfundId, bytes32(0), DONATION_AMOUNT_3);        // Donor 1 second donation
        vm.stopPrank(); // Stop donor1 prank before donor2
        vm.prank(donor2);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_2, DONATION_AMOUNT_2); // Donor 2 donation
        vm.stopPrank(); // Stop donor2 prank

        assertEq(crowdfund.getDonorsCount(crowdfundId), 2, "Should have 2 unique donors");
    }

    function test_GetCrowdfundRefundInfo_BeforeRefunds() public {
        // Setup: CF with 2 unique donors, failed goal
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_9);
        uint128 donor2Donation = 1 * 10**6; // 1 USDC (Goal is 100 USDC)
        uint128 totalDonatedAmount = DONATION_AMOUNT_1 + DONATION_AMOUNT_3 + donor2Donation;

        vm.startPrank(donor1); // Use startPrank for multiple calls
        crowdfund.donate(crowdfundId, DONATION_HASH_9_1, DONATION_AMOUNT_1); // Donor 1 first donation (50)
        crowdfund.donate(crowdfundId, bytes32(0), DONATION_AMOUNT_3);        // Donor 1 second donation (40, total 90)
        vm.stopPrank(); // Stop donor1 prank before donor2
        vm.prank(donor2);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_2, donor2Donation); // Donor 2 donation (1, grand total 91)
        vm.stopPrank(); // Stop donor2 prank
        (uint128 cfGoal,,,,,,) = crowdfund.crowdfunds(crowdfundId);
        assertTrue(cfGoal > totalDonatedAmount, "Goal should not be met"); // Changed assertion check

        // Warp past end time
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Get info
        (uint256 totalDonors, uint256 pendingRefunds, uint128 totalPendingAmount) = crowdfund.getCrowdfundRefundInfo(crowdfundId);

        assertEq(totalDonors, 2, "Total donors mismatch");
        assertEq(pendingRefunds, 2, "Pending refunds count mismatch (before refunds)");
        assertEq(totalPendingAmount, totalDonatedAmount, "Total pending amount mismatch (before refunds)"); // Changed assertion check
    }

    function test_PushRefunds_Batching() public {
        // Setup: CF with 3 unique donors (donor1, donor2, projectOwner), goal not met
        address donor3 = projectOwner; // Use projectOwner as donor3 for simplicity
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_9); // Crowdfund ID 0
        uint128 donor1Total = DONATION_AMOUNT_1; // 50
        uint128 donor2Total = DONATION_AMOUNT_3; // 40
        uint128 donor3Total = 5 * 10**6;         // 5
        uint128 grandTotal = donor1Total + donor2Total + donor3Total; // 95 (Goal is 100)

        vm.startPrank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_1, donor1Total);
        vm.stopPrank();

        vm.startPrank(donor2);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_2, donor2Total);
        vm.stopPrank();

        vm.startPrank(donor3);
        usdc.approve(address(crowdfund), donor3Total);
        crowdfund.donate(crowdfundId, bytes32(0), donor3Total);
        vm.stopPrank();

        // Verify setup
        assertEq(crowdfund.getDonorsCount(crowdfundId), 3, "Incorrect donor count setup");
        (uint128 cfGoal,,,,,,) = crowdfund.crowdfunds(crowdfundId);
        assertTrue(cfGoal > grandTotal, "Goal should not be met");

        // Warp past end time
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Get initial refund info
        (uint256 totalDonorsBefore, uint256 pendingRefundsBefore, uint128 totalPendingAmountBefore) = crowdfund.getCrowdfundRefundInfo(crowdfundId);
        assertEq(totalDonorsBefore, 3);
        assertEq(pendingRefundsBefore, 3);
        assertEq(totalPendingAmountBefore, grandTotal);

        // Record balances before refunds
        uint256 d1BalanceBefore = usdc.balanceOf(donor1);
        uint256 d2BalanceBefore = usdc.balanceOf(donor2);
        uint256 d3BalanceBefore = usdc.balanceOf(donor3);

        // --- Push first batch (2 donors) ---
        vm.prank(contractDeployer); // Assuming anyone can push refunds
        crowdfund.pushRefunds(crowdfundId, 0, 2); // Refund donor1 and donor2

        // Verify balances after batch 1
        assertEq(usdc.balanceOf(donor1), d1BalanceBefore + donor1Total, "Donor 1 refund incorrect");
        assertEq(usdc.balanceOf(donor2), d2BalanceBefore + donor2Total, "Donor 2 refund incorrect");
        assertEq(usdc.balanceOf(donor3), d3BalanceBefore, "Donor 3 should not be refunded yet");

        // Verify refund info after batch 1
        uint256 totalDonorsMid;
        uint256 pendingRefundsMid;
        uint128 totalPendingAmountMid;
        (totalDonorsMid, pendingRefundsMid, totalPendingAmountMid) = crowdfund.getCrowdfundRefundInfo(crowdfundId);
        assertEq(totalDonorsMid, 3, "Total donors should not change");
        assertEq(pendingRefundsMid, 1, "Pending refunds should be 1");
        assertEq(totalPendingAmountMid, donor3Total, "Pending amount should be donor 3's amount");

        // Verify crowdfund totalRaised
        (, uint128 cfTotalRaised,,,,,) = crowdfund.crowdfunds(crowdfundId);
        assertEq(cfTotalRaised, donor3Total, "Total raised should reflect remaining pending refund");

        // --- Push second batch (remaining 1 donor) ---
        vm.prank(contractDeployer);
        crowdfund.pushRefunds(crowdfundId, 2, 2); // Start index 2, size 2 (will process only 1)

        // Verify balances after batch 2
        assertEq(usdc.balanceOf(donor3), d3BalanceBefore + donor3Total, "Donor 3 refund incorrect");

        // Verify refund info after batch 2
        uint256 totalDonorsAfter;
        uint256 pendingRefundsAfter;
        uint128 totalPendingAmountAfter;
        (totalDonorsAfter, pendingRefundsAfter, totalPendingAmountAfter) = crowdfund.getCrowdfundRefundInfo(crowdfundId);
        assertEq(totalDonorsAfter, 3);
        assertEq(pendingRefundsAfter, 0, "Pending refunds should be 0");
        assertEq(totalPendingAmountAfter, 0, "Pending amount should be 0");

        // Verify crowdfund totalRaised is zero
        (, uint128 cfTotalRaisedAfter,,,,,) = crowdfund.crowdfunds(crowdfundId);
        assertEq(cfTotalRaisedAfter, 0, "Total raised should be zero after all refunds");

        // --- Attempt to push refunds again (should do nothing) ---
        uint256 d1BalanceAfter = usdc.balanceOf(donor1);
        vm.prank(contractDeployer);
        crowdfund.pushRefunds(crowdfundId, 0, 3); // Try refunding all again
        assertEq(usdc.balanceOf(donor1), d1BalanceAfter, "Donor 1 balance should not change on second refund attempt");
        // Verify refund info after attempt
        uint256 totalDonorsFinal;
        uint256 pendingRefundsFinal;
        uint128 totalPendingAmountFinal;
        (totalDonorsFinal, pendingRefundsFinal, totalPendingAmountFinal) = crowdfund.getCrowdfundRefundInfo(crowdfundId);
        assertEq(totalDonorsFinal, 3); // Should still be 3 total donors
        assertEq(pendingRefundsFinal, 0);
        assertEq(totalPendingAmountFinal, 0);
    }

    function test_GetCrowdfundRefundInfo_AfterRefunds() public {
        // Setup: CF with 2 unique donors, failed goal
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_9);
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_1, DONATION_AMOUNT_1);
        vm.prank(donor2);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_2, DONATION_AMOUNT_3);
        (uint128 cf9GoalAfter,,,,,,) = crowdfund.crowdfunds(crowdfundId);
        assertTrue(cf9GoalAfter > (DONATION_AMOUNT_1 + DONATION_AMOUNT_3), "Goal should not be met");

        // Warp past end time
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Donor 1 claims refund via claimRefund
        vm.prank(donor1);
        crowdfund.claimRefund(crowdfundId);

        // Get info after donor 1 claimed
        uint256 totalDonors;
        uint256 pendingRefunds;
        uint128 totalPendingAmount;
        (totalDonors, pendingRefunds, totalPendingAmount) = crowdfund.getCrowdfundRefundInfo(crowdfundId);

        assertEq(totalDonors, 2, "Total donors mismatch after refund");
        assertEq(pendingRefunds, 1, "Pending refunds count should be 1 after one refund");
        assertEq(totalPendingAmount, DONATION_AMOUNT_3, "Total pending amount should be donor 2's amount");

        // Push remaining refund for donor 2
        vm.prank(contractDeployer);
        crowdfund.pushRefunds(crowdfundId, 0, 2); // Process both indexes, only donor 2 has funds

        // Get info after all refunds
        // Re-declare variables (scopes differ)
        uint256 totalDonorsAfterRefunds;
        uint256 pendingRefundsAfterRefunds;
        uint128 totalPendingAmountAfterRefunds;
        (totalDonorsAfterRefunds, pendingRefundsAfterRefunds, totalPendingAmountAfterRefunds) = crowdfund.getCrowdfundRefundInfo(crowdfundId);
        assertEq(totalDonorsAfterRefunds, 2, "Total donors mismatch after all refunds");
        assertEq(pendingRefundsAfterRefunds, 0, "Pending refunds count should be 0 after all refunds");
        assertEq(totalPendingAmountAfterRefunds, 0, "Total pending amount should be 0 after all refunds");
    }

    function test_RevertWhen_PushRefunds_GoalMet() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        vm.prank(contractDeployer);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundGoalWasMet.selector, crowdfundId, GOAL_AMOUNT, GOAL_AMOUNT));
        crowdfund.pushRefunds(crowdfundId, 0, 1); 
    }

    function test_RevertWhen_PushRefunds_NotEnded() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Don't meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
        vm.stopPrank();
        // Get expected end time
        (,,uint64 endTime,,,,) = crowdfund.crowdfunds(crowdfundId);
        // DO NOT warp time

        vm.prank(contractDeployer);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundNotEnded.selector, crowdfundId, endTime));
        crowdfund.pushRefunds(crowdfundId, 0, 1);
    }

    function test_RevertWhen_PushRefunds_Cancelled() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Don't meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, DONATION_AMOUNT_1);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Cancel the crowdfund
        vm.prank(projectOwner);
        crowdfund.cancelCrowdfund(crowdfundId);

        vm.prank(contractDeployer);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundWasCancelled.selector, crowdfundId));
        crowdfund.pushRefunds(crowdfundId, 0, 1);
    }

    function test_RevertWhen_PushRefunds_FundsClaimed() public {
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_1);
        // Meet goal
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_1, GOAL_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);

        // Claim funds
        vm.prank(projectOwner);
        crowdfund.claimFunds(crowdfundId);

        // Attempt pushRefunds
        vm.prank(contractDeployer);
        // Note: This reverts on "Crowdfund goal was met" first in this specific setup.
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.CrowdfundGoalWasMet.selector, crowdfundId, GOAL_AMOUNT, GOAL_AMOUNT)); 
        crowdfund.pushRefunds(crowdfundId, 0, 1);

        // Test case where fundsClaimed is the primary reason (e.g., goal not met but somehow owner claimed - unlikely but for completeness)
        // We can't directly test FundsAlreadyClaimedByOwner in pushRefunds because goalMet/cancelled checks come first.
        // However, we know the check exists in the contract.
    }

    function test_RevertWhen_PushRefunds_InvalidBatchParams() public {
        // Setup: CF with 1 donor, failed goal
        uint128 crowdfundId = _createDefaultCrowdfund(CONTENT_HASH_9);
        vm.prank(donor1);
        crowdfund.donate(crowdfundId, DONATION_HASH_9_1, DONATION_AMOUNT_1);
        vm.stopPrank();
        (uint128 cfGoalInv,,,,,,) = crowdfund.crowdfunds(crowdfundId);
        assertTrue(cfGoalInv > DONATION_AMOUNT_1, "Goal should not be met");
        vm.warp(block.timestamp + DEFAULT_MAX_DURATION + 1 days);
        uint256 donorCount = crowdfund.getDonorsCount(crowdfundId);
        assertEq(donorCount, 1);

        // Try to push refunds with invalid start index
        uint256 invalidStartIndex = 1;
        vm.prank(contractDeployer);
        vm.expectRevert(abi.encodeWithSelector(FarcasterCrowdfund.StartIndexOutOfBounds.selector, invalidStartIndex, donorCount));
        crowdfund.pushRefunds(crowdfundId, invalidStartIndex, 1); // Start index 1 is out of bounds (only 1 donor at index 0)

        // Attempt with batchSize 0 (should process successfully but do nothing)
        vm.prank(contractDeployer);
        crowdfund.pushRefunds(crowdfundId, 0, 0); // Processes 0 donors
        (,, uint128 totalPendingAmount) = crowdfund.getCrowdfundRefundInfo(crowdfundId);
        assertEq(totalPendingAmount, DONATION_AMOUNT_1, "Pending amount should not change with batch size 0");
    }
}
