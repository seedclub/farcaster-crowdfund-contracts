// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FarcasterCrowdfund
 * @dev All-in-one contract for crowdfunding with NFT rewards by Seed Club
 * @notice Version 0.0.7`
 */
contract FarcasterCrowdfund is ERC721, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ----- Struct definitions -----

    // Crowdfund registry data structures
    struct Crowdfund {
        uint128 goal; // Amount in USDC (with 6 decimals)
        uint128 totalRaised; // Total amount raised in USDC (with 6 decimals)
        uint64 endTimestamp; // Timestamp when the crowdfund ends
        string contentId; // Content ID (string) facilitates proactive indexing on the offchain backend
        address owner; // Address of the crowdfund creator
        bool fundsClaimed; // Whether the funds have been claimed
        bool cancelled; // Whether the crowdfund has been cancelled
    }

    // ----- State variables optimized for packing -----

    // USDC token address - immutable, does not use storage after deployment
    IERC20 public immutable usdc;

    // Base URI for metadata (e.g. https://crowdfund.seedclub.xyz/metadata/{tokenId})
    string private _baseMetadataURI;

    // Counters
    uint128 private _tokenIdCounter;
    uint128 private _crowdfundIdCounter;
    
    // Time and state variables - can be packed together
    uint64 public maxDuration;
    bool public paused = false;

    // Mappings - cannot be packed
    // Maps NFT token IDs to their corresponding crowdfund IDs
    mapping(uint256 => uint128) public tokenToCrowdfund;
    // Track if a donor has received an NFT for a crowdfund
    mapping(uint128 => mapping(address => uint128)) public donorToTokenId;
    // Mapping from crowdfundId to Crowdfund data
    mapping(uint128 => Crowdfund) public crowdfunds;
    // Mapping from crowdfundId to donor address to amount donated
    mapping(uint128 => mapping(address => uint128)) public donations;
    // Track if an address is a donor for a specific crowdfund
    mapping(uint128 => mapping(address => bool)) public isDonor; 
    // Track if a content ID hash has been used (hash of "" is ignored)
    mapping(bytes32 => bool) public contentIdUsed;
    // Track if a donation ID hash has been used globally (hash of "" is ignored)
    mapping(bytes32 => bool) public donationIdUsed;

    // ----- Events -----

    event CrowdfundCreated(
        uint128 indexed crowdfundId,
        string indexed contentId,
        address indexed owner,
        uint128 fundingTarget,
        uint64 endTimestamp
    );

    event DonationReceived(
        uint128 indexed crowdfundId,
        string contentId,
        string indexed donationId,
        address indexed donor,
        uint128 amount
    );

    event FundsClaimed(
        uint128 indexed crowdfundId,
        string indexed contentId,
        address indexed owner,
        uint128 amount
    );

    event RefundIssued(
        uint128 indexed crowdfundId,
        string indexed contentId,
        address indexed donor,
        uint128 amount
    );

    event CrowdfundCancelled(
        uint128 indexed crowdfundId,
        string indexed contentId,
        address indexed owner
    );

    event NFTMinted(
        uint128 indexed crowdfundId,
        string indexed contentId,
        address indexed donor,
        uint128 tokenId
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
        uint64 oldMaxDuration,
        uint64 newMaxDuration,
        address indexed owner
    );

    // ----- Modifiers -----

    /**
     * @dev Modifier to check if a crowdfund exists
     * @param crowdfundId ID of the crowdfund to check
     */
    modifier crowdfundExists(uint128 crowdfundId) {
        require(
            crowdfundId < _crowdfundIdCounter &&
                crowdfunds[crowdfundId].owner != address(0),
            "Crowdfund does not exist"
        );
        _;
    }

    // ----- Constructor -----

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
        uint64 _maxDuration
    ) ERC721("Farcaster Crowdfund", "CROWDFUND") Ownable(initialOwner) {
        usdc = IERC20(_usdc);
        _baseMetadataURI = baseURI;
        maxDuration = _maxDuration > 0 ? _maxDuration : 7 days; // Default to 7 days if not specified
    }

    // ----- External state-changing functions -----

    /**
     * @dev Creates a new crowdfunding campaign
     * @param fundraisingTarget Target amount in USDC (with 6 decimals)
     * @param duration Duration in seconds for the crowdfund
     * @param contentId Content ID facilitates proactive indexing prior to the transaction landing onchain
     */
    function createCrowdfund(
        uint128 fundraisingTarget,
        uint64 duration,
        string memory contentId
    ) external returns (uint128) {
        require(!paused, "Contract is paused");
        require(fundraisingTarget > 0, "Goal must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(duration <= maxDuration, "Duration exceeds maximum allowed");

        // Check contentId uniqueness if not empty string
        bytes32 contentIdHash = keccak256(abi.encodePacked(contentId));
        if (contentIdHash != keccak256(abi.encodePacked(""))) {
            require(!contentIdUsed[contentIdHash], "Content ID already used. Please use a unique ID or \"\" for no content ID.");
            contentIdUsed[contentIdHash] = true;
        }

        uint128 crowdfundId = _crowdfundIdCounter;
        _crowdfundIdCounter++;

        crowdfunds[crowdfundId] = Crowdfund({
            goal: fundraisingTarget,
            totalRaised: 0,
            endTimestamp: uint64(block.timestamp) + duration,
            contentId: contentId,
            owner: msg.sender,
            fundsClaimed: false,
            cancelled: false
        });

        emit CrowdfundCreated(
            crowdfundId,
            contentId,
            msg.sender,
            fundraisingTarget,
            uint64(block.timestamp) + duration
        );

        return crowdfundId;
    }

    /**
     * @dev Donate USDC to a crowdfund
     * @param crowdfundId ID of the crowdfund to donate to
     * @param donationId Donation ID facilitates proactive indexing prior to the transaction landing onchain (0 if none)
     * @param amount Amount of USDC to donate (with 6 decimals)
     */
    function donate(
        uint128 crowdfundId,
        string memory donationId,
        uint128 amount
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(amount > 0, "Amount must be greater than 0");
        require(block.timestamp < cf.endTimestamp, "Crowdfund has ended");
        require(!cf.cancelled, "Crowdfund has been cancelled");

        // Check donationId uniqueness if not empty string
        bytes32 donationIdHash = keccak256(abi.encodePacked(donationId));
        if (donationIdHash != keccak256(abi.encodePacked(""))) {
            require(!donationIdUsed[donationIdHash], "Donation ID already used. Please use a unique ID or \"\" for no donation ID.");
            donationIdUsed[donationIdHash] = true;
        }

        // Track if this is a first-time donor to mint NFT
        if (!isDonor[crowdfundId][msg.sender]) {
            isDonor[crowdfundId][msg.sender] = true;
            // Mint NFT for first-time donors
            // Increment counter first to get the next token ID
            uint128 tokenId = _tokenIdCounter++;

            // Set mappings before minting to ensure proper state
            tokenToCrowdfund[tokenId] = crowdfundId;
            donorToTokenId[crowdfundId][msg.sender] = tokenId;

            // Use _safeMint for additional safety checks
            _safeMint(msg.sender, tokenId);

            emit NFTMinted(crowdfundId, cf.contentId, msg.sender, tokenId);
        }

        donations[crowdfundId][msg.sender] += amount;
        cf.totalRaised += amount;

        // Transfer USDC from donor to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit DonationReceived(crowdfundId, cf.contentId, donationId, msg.sender, amount);
    }

    /**
     * @dev Allows the crowdfund creator to claim funds if goal is met
     * @param crowdfundId ID of the crowdfund
     */
    function claimFunds(
        uint128 crowdfundId
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
        uint128 crowdfundId
    ) external nonReentrant crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(
            (block.timestamp >= cf.endTimestamp && cf.totalRaised < cf.goal) ||
                cf.cancelled,
            "Refunds not available - either goal met or crowdfund still active"
        );
        require(!cf.fundsClaimed, "Funds already claimed by owner");

        uint128 donationAmount = donations[crowdfundId][msg.sender];
        require(donationAmount > 0, "No donation to refund");

        // Effects: Reset donation amount to prevent re-entrancy

        donations[crowdfundId][msg.sender] = 0;

        // Decrease the totalRaised amount
        cf.totalRaised -= donationAmount;

        // Interaction: Transfer USDC back to the donor
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
        uint128 crowdfundId
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(msg.sender == cf.owner, "Not the crowdfund owner");
        require(!cf.fundsClaimed, "Funds already claimed");
        require(!cf.cancelled, "Already cancelled");

        cf.cancelled = true;

        emit CrowdfundCancelled(crowdfundId, cf.contentId, cf.owner);
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
    function setMaxDuration(uint64 _maxDuration) external onlyOwner {
        require(_maxDuration > 0, "Duration must be greater than 0");
        uint64 oldMaxDuration = maxDuration;
        maxDuration = _maxDuration;
        emit MaxDurationUpdated(oldMaxDuration, _maxDuration, msg.sender);
    }

    // ----- External view functions -----

    /**
     * @dev Returns the token ID for a donor of a specific crowdfund
     * @param crowdfundId ID of the crowdfund
     * @param donor Address of the donor
     * @return tokenId The donor's NFT token ID (0 if none)
     */
    function getDonorTokenId(
        uint128 crowdfundId,
        address donor
    ) external view crowdfundExists(crowdfundId) returns (uint128) {
        return donorToTokenId[crowdfundId][donor];
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

    // ----- Internal pure functions -----

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