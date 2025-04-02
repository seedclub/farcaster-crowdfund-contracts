// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FarcasterCrowdfund
 * @dev All-in-one contract for crowdfunding with NFT rewards by Seed Club
 */
contract FarcasterCrowdfund is ERC721, Ownable {
    using SafeERC20 for IERC20;

    // State variables for NFT functionality
    uint256 private _tokenIdCounter;
    // Maps NFT token IDs to their corresponding crowdfund IDs
    mapping(uint256 => uint256) public tokenToCrowdfund;
    // Track if a donor has received an NFT for a crowdfund
    mapping(uint256 => mapping(address => uint256)) public donorToTokenId;

    // Base URI for metadata (e.g. https://crowdfund.seedclub.xyz/metadata/{tokenId})
    string private _baseMetadataURI;

    // Pause state for crowdfund creation
    bool public paused = false;

    // Maximum duration for crowdfunds
    uint256 public maxDuration;

    // USDC token address
    IERC20 public immutable usdc;

    // Crowdfund registry data structures
    struct Crowdfund {
        address owner; // Address of the crowdfund creator
        uint256 goal; // Amount in USDC (with 6 decimals)
        uint256 endTimestamp; // Timestamp when the crowdfund ends
        uint256 totalRaised; // Total amount raised in USDC (with 6 decimals)
        bool fundsClaimed; // Whether the funds have been claimed
        bool cancelled; // Whether the crowdfund has been cancelled
        uint256 contentId; // Content ID facilitates proactive indexing on the offchain backend
    }

    // Track crowdfunds count
    uint256 private _crowdfundIdCounter;

    // Mapping from crowdfundId to Crowdfund data
    mapping(uint256 => Crowdfund) public crowdfunds;

    // Mapping from crowdfundId to donor address to amount donated
    mapping(uint256 => mapping(address => uint256)) public donations;

    // Track all donors for each crowdfund (for NFT claims)
    mapping(uint256 => address[]) private _crowdfundDonors;
    mapping(uint256 => mapping(address => bool)) public isDonor; 

    // Events
    event CrowdfundCreated(
        uint256 indexed crowdfundId,
        uint256 indexed contentId,
        address indexed owner,
        uint256 fundingTarget,
        uint256 endTimestamp
    );

    event DonationReceived(
        uint256 indexed crowdfundId,
        uint256 contentId,
        uint256 indexed donationId,
        address indexed donor,
        uint256 amount
    );

    event FundsClaimed(
        uint256 indexed crowdfundId,
        uint256 indexed contentId,
        address indexed owner,
        uint256 amount
    );

    event RefundIssued(
        uint256 indexed crowdfundId,
        uint256 indexed contentId,
        address indexed donor,
        uint256 amount
    );

    event CrowdfundCancelled(
        uint256 indexed crowdfundId,
        uint256 indexed contentId,
        address indexed owner
    );

    event NFTMinted(
        uint256 indexed crowdfundId,
        uint256 indexed contentId,
        address indexed donor,
        uint256 tokenId
    );

    // Admin events
    event BaseURIUpdated(
        string oldBaseURI,
        string newBaseURI,
        address indexed owner
    );

    event PauseStateUpdated(
        bool oldPauseState,
        bool newPauseState,
        address indexed owner
    );

    event MaxDurationUpdated(
        uint256 oldMaxDuration,
        uint256 newMaxDuration,
        address indexed owner
    );

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
        require(
            crowdfundId < _crowdfundIdCounter &&
                crowdfunds[crowdfundId].owner != address(0),
            "Crowdfund does not exist"
        );
        _;
    }

    /**
     * @dev Creates a new crowdfunding campaign
     * @param fundraisingTarget Target amount in USDC (with 6 decimals)
     * @param duration Duration in seconds for the crowdfund
     * @param contentId Content ID facilitates proactive indexing prior to the transaction landing onchain
     */
    function createCrowdfund(
        uint256 fundraisingTarget,
        uint256 duration,
        uint256 contentId
    ) external returns (uint256) {
        require(!paused, "Contract is paused");
        require(fundraisingTarget > 0, "Goal must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(duration <= maxDuration, "Duration exceeds maximum allowed");

        uint256 crowdfundId = _crowdfundIdCounter;
        _crowdfundIdCounter++;

        crowdfunds[crowdfundId] = Crowdfund({
            owner: msg.sender,
            goal: fundraisingTarget,
            endTimestamp: block.timestamp + duration,
            totalRaised: 0,
            fundsClaimed: false,
            cancelled: false,
            contentId: contentId
        });

        emit CrowdfundCreated(
            crowdfundId,
            contentId,
            msg.sender,
            fundraisingTarget,
            block.timestamp + duration
        );

        return crowdfundId;
    }

    /**
     * @dev Donate USDC to a crowdfund1
     * @param crowdfundId ID of the crowdfund to donate to
     * @param amount Amount of USDC to donate (with 6 decimals)
     * @param donationId Donation ID facilitates proactive indexing prior to the transaction landing onchain (0 if none)
     */
    function donate(
        uint256 crowdfundId,
        uint256 amount,
        uint256 donationId 
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(amount > 0, "Amount must be greater than 0");
        require(block.timestamp < cf.endTimestamp, "Crowdfund has ended");
        require(!cf.cancelled, "Crowdfund has been cancelled");

        // Track if this is a first-time donor to mint NFT
        bool isFirstDonation = !isDonor[crowdfundId][msg.sender];

        // Update donation records
        if (isFirstDonation) {
            _crowdfundDonors[crowdfundId].push(msg.sender);
            isDonor[crowdfundId][msg.sender] = true;
        }

        donations[crowdfundId][msg.sender] += amount;
        cf.totalRaised += amount;

        // Transfer USDC from donor to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit DonationReceived(crowdfundId, cf.contentId, donationId, msg.sender, amount);

        // Mint an NFT for first-time donors
        if (isFirstDonation) {
            // Increment counter first to get the next token ID
            uint256 tokenId = _tokenIdCounter++;

            // Set mappings before minting to ensure proper state
            tokenToCrowdfund[tokenId] = crowdfundId;
            donorToTokenId[crowdfundId][msg.sender] = tokenId;

            // Use _safeMint for additional safety checks
            _safeMint(msg.sender, tokenId);

            emit NFTMinted(crowdfundId, cf.contentId, msg.sender, tokenId);
        }
    }

    /**
     * @dev Allows the crowdfund creator to claim funds if goal is met
     * @param crowdfundId ID of the crowdfund
     */
    function claimFunds(
        uint256 crowdfundId
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(msg.sender == cf.owner, "Not the crowdfund owner");
        require(block.timestamp > cf.endTimestamp, "Crowdfund not ended yet");
        require(cf.totalRaised >= cf.goal, "Goal not met");
        require(!cf.fundsClaimed, "Funds already claimed");
        require(!cf.cancelled, "Crowdfund has been cancelled");

        cf.fundsClaimed = true;

        // Transfer all USDC to the creator
        usdc.safeTransfer(cf.owner, cf.totalRaised);

        emit FundsClaimed(crowdfundId, cf.contentId, cf.owner, cf.totalRaised);
    }

    /**
     * @dev Allows donors to claim refunds if goal is not met and crowdfund ended
     * @param crowdfundId ID of the crowdfund
     */
    function claimRefund(
        uint256 crowdfundId
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(
            (block.timestamp >= cf.endTimestamp && cf.totalRaised < cf.goal) ||
                cf.cancelled,
            "Refunds not available - either goal met or crowdfund still active"
        );
        require(!cf.fundsClaimed, "Funds already claimed by owner");

        uint256 donationAmount = donations[crowdfundId][msg.sender];
        require(donationAmount > 0, "No donation to refund");

        // Reset donation amount to prevent re-entrancy
        donations[crowdfundId][msg.sender] = 0;

        // Decrease the totalRaised amount
        cf.totalRaised -= donationAmount;

        // Transfer USDC back to the donor
        usdc.safeTransfer(msg.sender, donationAmount);

        emit RefundIssued(
            crowdfundId,
            cf.contentId,
            msg.sender,
            donationAmount
        );
    }

    /**
     * @dev Allows the owner to cancel a crowdfund
     * @param crowdfundId ID of the crowdfund
     */
    function cancelCrowdfund(
        uint256 crowdfundId
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(msg.sender == cf.owner, "Not the crowdfund owner");
        require(!cf.fundsClaimed, "Funds already claimed");
        require(!cf.cancelled, "Already cancelled");

        cf.cancelled = true;

        emit CrowdfundCancelled(crowdfundId, cf.contentId, cf.owner);
    }

    /**
     * @dev Returns the token ID for a donor of a specific crowdfund
     * @param crowdfundId ID of the crowdfund
     * @param donor Address of the donor
     * @return tokenId The donor's NFT token ID (0 if none)
     */
    function getDonorTokenId(
        uint256 crowdfundId,
        address donor
    ) external view crowdfundExists(crowdfundId) returns (uint256) {
        return donorToTokenId[crowdfundId][donor];
    }

    /**
     * @dev Returns the list of donors for a crowdfund
     * @param crowdfundId ID of the crowdfund
     */
    function getDonors(
        uint256 crowdfundId
    ) external view crowdfundExists(crowdfundId) returns (address[] memory) {
        return _crowdfundDonors[crowdfundId];
    }

    /**
     * @dev Update the base metadata URI (only callable by owner)
     * @param newBaseURI The new base URI for metadata
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        string memory oldBaseURI = _baseMetadataURI;
        _baseMetadataURI = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI, msg.sender);
    }

    /**
     * @dev Toggle the paused state (only callable by owner)
     * @param _paused New paused state
     */
    function setPaused(bool _paused) external onlyOwner {
        bool oldPauseState = paused;
        paused = _paused;
        emit PauseStateUpdated(oldPauseState, _paused, msg.sender);
    }

    /**
     * @dev Update the maximum allowed duration for crowdfunds (only callable by owner)
     * @param _maxDuration New maximum duration in seconds
     */
    function setMaxDuration(uint256 _maxDuration) external onlyOwner {
        require(_maxDuration > 0, "Duration must be greater than 0");
        uint256 oldMaxDuration = maxDuration;
        maxDuration = _maxDuration;
        emit MaxDurationUpdated(oldMaxDuration, _maxDuration, msg.sender);
    }

    /**
     * @dev Custom token URI that points to your existing metadata endpoint
     * @param tokenId ID of the token
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        return string(abi.encodePacked(_baseMetadataURI, toString(tokenId)));
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