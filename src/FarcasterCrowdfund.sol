// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title FarcasterCrowdfund
 * @dev All-in-one contract for crowdfunding with NFT rewards
 */
contract FarcasterCrowdfund is ERC721, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    
    // State variables for NFT functionality
    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => uint256) public tokenToCrowdfund;
    // Track if a donor has received an NFT for a crowdfund
    mapping(uint256 => mapping(address => uint256)) public donorToTokenId;
    
    // Base URI for metadata
    string private _baseMetadataURI;
    
    // Pause state for crowdfund creation
    bool public paused = false;
    
    // Maximum duration for crowdfunds
    uint256 public maxDuration;
    
    // USDC token address
    IERC20 public immutable usdc;
    
    // Crowdfund registry data structures
    struct Crowdfund {
        address owner;
        uint256 goal;
        uint256 endTimestamp;
        uint256 totalRaised;
        bool fundsClaimed;
        bool cancelled;
        uint256 fid; // Optional Farcaster ID (0 if not set)
    }
    
    // Track crowdfunds count
    Counters.Counter private _crowdfundIdCounter;
    
    // Mapping from crowdfundId to Crowdfund data
    mapping(uint256 => Crowdfund) public crowdfunds;
    
    // Mapping from crowdfundId to donor address to amount donated
    mapping(uint256 => mapping(address => uint256)) public donations;
    
    // Track all donors for each crowdfund (for NFT claims)
    mapping(uint256 => address[]) private _crowdfundDonors;
    mapping(uint256 => mapping(address => bool)) private _isDonor;
    
    // No need to store comments on-chain - just emit in events
    
    // Events
    event CrowdfundCreated(uint256 indexed crowdfundId, address indexed owner, string goal, string description, uint256 goal, uint256 endTimestamp, uint256 fid);
    event DonationReceived(uint256 indexed crowdfundId, address indexed donor, uint256 amount, string comment);
    event FundsClaimed(uint256 indexed crowdfundId, address indexed owner, uint256 amount);
    event RefundIssued(uint256 indexed crowdfundId, address indexed donor, uint256 amount);
    event CrowdfundCancelled(uint256 indexed crowdfundId);
    event NFTMinted(uint256 indexed crowdfundId, address indexed donor, uint256 tokenId);
    
    /**
     * @dev Constructor sets up the ERC721 token and USDC address
     * @param _usdc The address of the USDC token contract
     * @param initialOwner The initial owner of the contract
     * @param baseURI The base URI for NFT metadata
     * @param _maxDuration The maximum duration allowed for crowdfunds (in seconds)
     */
    constructor(
        address _usdc, 
        address initialOwner, 
        string memory baseURI,
        uint256 _maxDuration
    ) ERC721("Farcaster Crowdfund", "CROWDFUND") Ownable(initialOwner) {
        usdc = IERC20(_usdc);
        _baseMetadataURI = baseURI;
        maxDuration = _maxDuration > 0 ? _maxDuration : 7 days; // Default to 7 days if not specified
    }
    
    /**
     * @dev Modifier to check if a crowdfund exists
     * @param crowdfundId ID of the crowdfund to check
     */
    modifier crowdfundExists(uint256 crowdfundId) {
        require(crowdfundId < _crowdfundIdCounter.current() && 
               crowdfunds[crowdfundId].owner != address(0),
               "Crowdfund does not exist");
        _;
    }

    /**
     * @dev Creates a new crowdfunding campaign
     * @param Goal Goal of the crowdfund
     * @param description Description of the crowdfund
     * @param goal Target amount in USDC (with 6 decimals)
     * @param duration Duration in seconds for the crowdfund
     * @param fid Optional Farcaster ID (0 if not used)
     */
    function createCrowdfund(
        string calldata goal,
        string calldata description,
        uint256 goal,
        uint256 duration,
        uint256 fid
    ) external returns (uint256) {
        require(!paused, "Contract is paused");
        require(goal > 0, "Goal must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(duration <= maxDuration, "Duration exceeds maximum allowed");
        
        uint256 crowdfundId = _crowdfundIdCounter.current();
        _crowdfundIdCounter.increment();
        
        crowdfunds[crowdfundId] = Crowdfund({
            owner: msg.sender,
            goal: goal,
            endTimestamp: block.timestamp + duration,
            totalRaised: 0,
            fundsClaimed: false,
            cancelled: false,
            fid: fid
        });
        
        // Emit goal and description in the event for off-chain indexing
        emit CrowdfundCreated(crowdfundId, msg.sender, goal, description, goal, block.timestamp + duration, fid);
        
        return crowdfundId;
    }
    
    /**
     * @dev Donate USDC to a crowdfund
     * @param crowdfundId ID of the crowdfund to donate to
     * @param amount Amount of USDC to donate (with 6 decimals)
     * @param comment Optional comment with the donation
     */
    function donate(uint256 crowdfundId, uint256 amount, string calldata comment) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];
        
        require(amount > 0, "Amount must be greater than 0");
        require(block.timestamp < cf.endTimestamp, "Crowdfund has ended");
        require(!cf.cancelled, "Crowdfund has been cancelled");
        
        // Track if this is a first-time donor to mint NFT
        bool isFirstDonation = !_isDonor[crowdfundId][msg.sender];
        
        // Update donation records
        if (isFirstDonation) {
            _crowdfundDonors[crowdfundId].push(msg.sender);
            _isDonor[crowdfundId][msg.sender] = true;
        }
        
        donations[crowdfundId][msg.sender] += amount;
        cf.totalRaised += amount;
        
        // No need to store comments - just emit in the event
        
        // Transfer USDC from donor to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        emit DonationReceived(crowdfundId, msg.sender, amount, comment);
        
        // Mint an NFT for first-time donors
        if (isFirstDonation) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            
            tokenToCrowdfund[tokenId] = crowdfundId;
            donorToTokenId[crowdfundId][msg.sender] = tokenId;
            
            _safeMint(msg.sender, tokenId);
            
            emit NFTMinted(crowdfundId, msg.sender, tokenId);
        }
    }
    
    /**
     * @dev Allows the crowdfund creator to claim funds if goal is met
     * @param crowdfundId ID of the crowdfund
     */
    function claimFunds(uint256 crowdfundId) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];
        
        require(msg.sender == cf.owner, "Not the crowdfund owner");
        require(block.timestamp > cf.endTimestamp, "Crowdfund not ended yet");
        require(cf.totalRaised >= cf.goal, "Goal not met");
        require(!cf.fundsClaimed, "Funds already claimed");
        require(!cf.cancelled, "Crowdfund has been cancelled");
        
        cf.fundsClaimed = true;
        
        // Transfer all USDC to the creator
        usdc.safeTransfer(cf.owner, cf.totalRaised);
        
        emit FundsClaimed(crowdfundId, cf.owner, cf.totalRaised);
    }
    
    /**
     * @dev Allows donors to claim refunds if goal is not met and crowdfund ended
     * @param crowdfundId ID of the crowdfund
     */
    function claimRefund(uint256 crowdfundId) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];
        
        require(
            (block.timestamp >= cf.endTimestamp && cf.totalRaised < cf.goal) || cf.cancelled,
            "Refunds not available - either goal met or crowdfund still active"
        );
        require(!cf.fundsClaimed, "Funds already claimed by owner");
        
        uint256 donationAmount = donations[crowdfundId][msg.sender];
        require(donationAmount > 0, "No donation to refund");
        
        // Reset donation amount to prevent re-entrancy
        donations[crowdfundId][msg.sender] = 0;
        
        // BUG FIX: Also decrease the totalRaised amount
        cf.totalRaised -= donationAmount;
        
        // Transfer USDC back to the donor
        usdc.safeTransfer(msg.sender, donationAmount);
        
        emit RefundIssued(crowdfundId, msg.sender, donationAmount);
    }
    
    /**
     * @dev Allows the owner to cancel a crowdfund
     * @param crowdfundId ID of the crowdfund
     */
    function cancelCrowdfund(uint256 crowdfundId) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];
        
        require(msg.sender == cf.owner, "Not the crowdfund owner");
        require(!cf.fundsClaimed, "Funds already claimed");
        require(!cf.cancelled, "Already cancelled");
        
        cf.cancelled = true;
        
        emit CrowdfundCancelled(crowdfundId);
    }
    
    /**
     * @dev Returns the token ID for a donor of a specific crowdfund
     * @param crowdfundId ID of the crowdfund
     * @param donor Address of the donor
     * @return tokenId The donor's NFT token ID (0 if none)
     */
    function getDonorTokenId(uint256 crowdfundId, address donor) external view crowdfundExists(crowdfundId) returns (uint256) {
        return donorToTokenId[crowdfundId][donor];
    }
    
    /**
     * @dev Returns the list of donors for a crowdfund
     * @param crowdfundId ID of the crowdfund
     */
    function getDonors(uint256 crowdfundId) external view crowdfundExists(crowdfundId) returns (address[] memory) {
        return _crowdfundDonors[crowdfundId];
    }
    
    /**
     * @dev Update the base metadata URI (only callable by owner)
     * @param newBaseURI The new base URI for metadata
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseMetadataURI = newBaseURI;
    }
    
    /**
     * @dev Toggle the paused state (only callable by owner)
     * @param _paused New paused state
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    /**
     * @dev Update the maximum allowed duration for crowdfunds (only callable by owner)
     * @param _maxDuration New maximum duration in seconds
     */
    function setMaxDuration(uint256 _maxDuration) external onlyOwner {
        require(_maxDuration > 0, "Duration must be greater than 0");
        maxDuration = _maxDuration;
    }
    
    /**
     * @dev Custom token URI that points to your existing metadata endpoint
     * @param tokenId ID of the token
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        uint256 crowdfundId = tokenToCrowdfund[tokenId];
        
        return string(abi.encodePacked(
            _baseMetadataURI,
            toString(crowdfundId),
            "/",
            toString(tokenId)
        ));
    }
    
    /**
     * @dev Utility function to convert uint to string
     * @param value The uint value to convert
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}