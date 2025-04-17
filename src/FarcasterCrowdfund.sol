// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FarcasterCrowdfund
 * @dev Time-limited USDC crowdfunds that issue commemorative NFTs to donors. Permissionless, open source, with no royalties or admin control over funds raised.
 * @notice Version 0.0.9
 */
contract FarcasterCrowdfund is ERC721, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ----- Struct definitions -----

    // Crowdfund registry data structures
    struct Crowdfund {
        uint128 goal; // Amount in USDC (with 6 decimals)
        uint128 totalRaised; // Total amount raised in USDC (with 6 decimals)
        uint64 endTimestamp; // Timestamp when the crowdfund ends
        bytes32 contentIdHash; // Hash of the Content ID. Facilitates indexing offchain. bytes32(0) if none
        address owner; // Address of the crowdfund creator
        bool fundsClaimed; // Whether the funds have been claimed
        bool cancelled; // Whether the crowdfund has been cancelled
    }

    // ----- State variables -----

    // USDC token address on this
    IERC20 public immutable usdc;

    // Base URI for metadata (e.g. https://crowdfund.seedclub.com/crowdfund/})
    string private _baseMetadataURI;

    // Counters
    uint128 private _tokenIdCounter = 1;
    uint128 private _crowdfundIdCounter;

    // Time and state variables - can be packed together
    uint64 public maxDuration;

    // Mappings - cannot be packed
    // Maps NFT token IDs to their corresponding crowdfund IDs
    mapping(uint256 => uint128) public tokenToCrowdfund;
    // Track if a donor has received an NFT for a crowdfund
    mapping(uint128 => mapping(address => uint128)) public donorToTokenId;
    // Mapping from crowdfundId to Crowdfund data
    mapping(uint128 => Crowdfund) public crowdfunds;
    // Mapping from crowdfundId to donor address to amount donated
    mapping(uint128 => mapping(address => uint128)) public donations;
    // Track if a content ID hash has been used (hash of "" is ignored)
    mapping(bytes32 => bool) public contentIdHashUsed;
    // Track if a donation ID hash has been used globally (hash of "" is ignored)
    mapping(bytes32 => bool) public donationIdHashUsed;

    // ----- Events -----

    event CrowdfundCreated(
        uint128 indexed crowdfundId,
        bytes32 indexed contentIdHash,
        address indexed owner,
        uint128 fundingTarget,
        uint64 endTimestamp
    );

    event DonationReceived(
        uint128 indexed crowdfundId,
        bytes32 contentIdHash,
        bytes32 indexed donationIdHash,
        address indexed donor,
        uint128 amount
    );

    event FundsClaimed(
        uint128 indexed crowdfundId,
        bytes32 indexed contentIdHash,
        address indexed owner,
        uint128 amount
    );

    event RefundIssued(
        uint128 indexed crowdfundId,
        bytes32 indexed contentIdHash,
        address indexed donor,
        uint128 amount
    );

    event CrowdfundCancelled(
        uint128 indexed crowdfundId,
        bytes32 indexed contentIdHash,
        address indexed owner
    );

    event NFTMinted(
        uint128 indexed crowdfundId,
        bytes32 indexed contentIdHash,
        address indexed donor,
        uint128 tokenId
    );

    // Admin events
    event BaseURIUpdated(
        string oldBaseURI,
        string newBaseURI
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
     * @notice Creates a new crowdfund campaign.
     * @param fundraisingTarget Target amount in USDC (with 6 decimals)
     * @param duration Duration in seconds for the crowdfund
     * @param contentIdHash Hash of the Content ID (bytes32(0) if none). Facilitates proactive indexing prior to the transaction landing onchain.
     */
    function createCrowdfund(
        uint128 fundraisingTarget,
        uint64 duration,
        bytes32 contentIdHash
    ) external whenNotPaused returns (uint128) {
        require(fundraisingTarget > 0, "Goal must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(duration <= maxDuration, "Duration exceeds maximum allowed");

        // Check contentId uniqueness if not empty hash
        if (contentIdHash != bytes32(0)) {
            require(
                !contentIdHashUsed[contentIdHash],
                "Content ID hash already used. Please use a unique hash or bytes32(0)."
            );
            contentIdHashUsed[contentIdHash] = true;
        }

        uint128 crowdfundId = _crowdfundIdCounter;
        _crowdfundIdCounter++;

        crowdfunds[crowdfundId] = Crowdfund({
            goal: fundraisingTarget,
            totalRaised: 0,
            endTimestamp: uint64(block.timestamp) + duration,
            contentIdHash: contentIdHash,
            owner: msg.sender,
            fundsClaimed: false,
            cancelled: false
        });

        emit CrowdfundCreated(
            crowdfundId,
            contentIdHash,
            msg.sender,
            fundraisingTarget,
            uint64(block.timestamp) + duration
        );

        return crowdfundId;
    }

    /**
     * @dev Donate USDC to a crowdfund
     * @notice Allows a user to donate USDC to a specific crowdfund and receive a commemorative NFT for their first donation.
     * @param crowdfundId ID of the crowdfund to donate to
     * @param donationIdHash Hash of the Donation ID. Facilitates proactive indexing.  bytes32(0) if none.
     * @param amount Amount of USDC to donate (with 6 decimals)
     */
    function donate(
        uint128 crowdfundId,
        bytes32 donationIdHash,
        uint128 amount
    ) external whenNotPaused crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(amount > 0, "Amount must be greater than 0");
        require(block.timestamp < cf.endTimestamp, "Crowdfund has ended");
        require(!cf.cancelled, "Crowdfund has been cancelled");

        // Check donationId uniqueness if not empty hash
        if (donationIdHash != bytes32(0)) {
            require(
                !donationIdHashUsed[donationIdHash],
                "Donation ID hash already used. Please use a unique hash or bytes32(0)."
            );
            donationIdHashUsed[donationIdHash] = true;
        }

        // Track if this is a first-time donor to mint NFT
        if (donorToTokenId[crowdfundId][msg.sender] == 0) {
            // Mint NFT for first-time donors
            // Increment counter first to get the next token ID
            uint128 tokenId = _tokenIdCounter++;

            // Set mappings before minting to ensure proper state
            tokenToCrowdfund[tokenId] = crowdfundId;
            donorToTokenId[crowdfundId][msg.sender] = tokenId;

            // Use _safeMint for additional safety checks
            _safeMint(msg.sender, tokenId);

            emit NFTMinted(crowdfundId, cf.contentIdHash, msg.sender, tokenId);
        }

        donations[crowdfundId][msg.sender] += amount;
        cf.totalRaised += amount;

        // Transfer USDC from donor to this contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit DonationReceived(
            crowdfundId,
            cf.contentIdHash,
            donationIdHash,
            msg.sender,
            amount
        );
    }

    /**
     * @dev Allows the crowdfund creator to claim funds if goal is met
     * @notice Allows the crowdfund owner to claim the raised funds if the goal is met after the end date.
     * @param crowdfundId ID of the crowdfund
     */
    function claimFunds(
        uint128 crowdfundId
    ) external whenNotPaused crowdfundExists(crowdfundId) nonReentrant {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        require(msg.sender == cf.owner, "Only the owner can claim funds");
        require(block.timestamp > cf.endTimestamp, "Crowdfund not ended yet");
        require(cf.totalRaised >= cf.goal, "Goal not met");
        require(!cf.fundsClaimed, "Funds already claimed");
        require(!cf.cancelled, "Crowdfund has been cancelled");

        cf.fundsClaimed = true;

        // Transfer all USDC to the creator
        usdc.safeTransfer(cf.owner, cf.totalRaised);

        emit FundsClaimed(
            crowdfundId,
            cf.contentIdHash,
            cf.owner,
            cf.totalRaised
        );
    }

    /**
     * @dev Allows donors to claim refunds if goal is not met and crowdfund ended
     * @notice Allows donors to reclaim their donated USDC if the crowdfund goal is not met by the end date or if the crowdfund is cancelled.
     * @param crowdfundId ID of the crowdfund
     */
    function claimRefund(
        uint128 crowdfundId
    ) external whenNotPaused crowdfundExists(crowdfundId) nonReentrant {
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
            cf.contentIdHash,
            msg.sender,
            donationAmount
        );
    }

    /**
     * @dev Allows the owner to cancel a crowdfund
     * @notice Allows the crowdfund owner to cancel the campaign before it ends, enabling refunds.
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

        emit CrowdfundCancelled(crowdfundId, cf.contentIdHash, cf.owner);
    }

    /**
     * @dev Update the base metadata URI (only callable by owner)
     * @notice (Owner only) Updates the base URI used for NFT metadata URLs.
     * @param newBaseURI The new base URI for metadata
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        string memory oldBaseURI = _baseMetadataURI;
        _baseMetadataURI = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI);
    }

    /**
     * @dev Update the maximum allowed duration for crowdfunds (only callable by owner)
     * @notice (Owner only) Sets the maximum allowed duration for new crowdfunds.
     * @param _maxDuration New maximum duration in seconds
     */
    function setMaxDuration(uint64 _maxDuration) external onlyOwner {
        require(_maxDuration > 0, "Duration must be greater than 0");
        uint64 oldMaxDuration = maxDuration;
        maxDuration = _maxDuration;
        emit MaxDurationUpdated(oldMaxDuration, _maxDuration, msg.sender);
    }

    /**
     * @dev Allows the contract owner to rescue any ERC20 tokens other than USDC
     * @param tokenAddress Address of the ERC20 token to be rescued
     * @param to Address to send the tokens to
     * @param amount Amount of tokens to rescue
     */
    function rescueERC20(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(tokenAddress != address(usdc), "Cannot withdraw USDC");
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(to, amount);
    }

    /**
     * @dev Pause the contract (only owner)
     * @notice Uses OpenZeppelin Pausable _pause function.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (only owner)
     * @notice Uses OpenZeppelin Pausable _unpause function.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ----- External view functions -----

    /**
     * @dev Custom token URI that points to a metadata endpoint that's the same across all NFTs from a given crowdfund
     * @notice Returns the metadata URI for a given NFT token ID.
     * @param tokenId ID of the token
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        return string(abi.encodePacked(_baseMetadataURI, toString(tokenToCrowdfund[tokenId])));
    }

    // ----- Receive and fallback functions -----

    /**
     * @dev Prevents ETH from being sent to non-existent functions or directly
     */
    fallback() external {
        revert("Function not found or ETH transfers not accepted");
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
