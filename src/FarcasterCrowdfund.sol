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
 * @notice Version 0.1.0
 */
contract FarcasterCrowdfund is ERC721, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ----- Custom Errors -----
    error CrowdfundDoesNotExist(uint128 crowdfundId);
    error InvalidFundingTarget(uint128 fundraisingTarget);
    error InvalidDuration(uint64 duration);
    error DurationExceedsMax(uint64 duration, uint64 maxDuration);
    error ContentIdHashAlreadyUsed(bytes32 contentIdHash);
    error AmountMustBeGreaterThanZero(uint128 amount);
    error CrowdfundHasEnded(uint128 crowdfundId, uint64 endTimestamp);
    error ErrorCrowdfundCancelled(uint128 crowdfundId);
    error DonationIdHashAlreadyUsed(bytes32 donationIdHash);
    error CrowdfundOwnerRequired(uint128 crowdfundId, address caller, address owner);
    error CrowdfundNotEnded(uint128 crowdfundId, uint64 endTimestamp);
    error GoalNotMet(uint128 crowdfundId, uint128 goal, uint128 totalRaised);
    error FundsAlreadyClaimed(uint128 crowdfundId);
    error RefundsNotAvailable(uint128 crowdfundId);
    error NoDonationToRefund(uint128 crowdfundId, address donor);
    error CrowdfundGoalWasMet(uint128 crowdfundId, uint128 goal, uint128 totalRaised);
    error CrowdfundWasCancelled(uint128 crowdfundId);
    error FundsAlreadyClaimedByOwner(uint128 crowdfundId);
    error StartIndexOutOfBounds(uint256 startIndex, uint256 count);
    error CannotWithdrawUSDC();
    error TokenDoesNotExist(uint256 tokenId);
    error FunctionNotFoundOrEthNotAccepted();

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

    // Maximum duration for crowdfunds
    uint64 public maxDuration;

    // Mappings
    // Maps NFT token IDs to their corresponding crowdfund IDs
    mapping(uint256 => uint128) public tokenToCrowdfund;
    // Tracks if a donor has donated to a crowdfund, and which NFT tokenId they received
    // Maps crowdfundId to donor address to NFT token ID
    mapping(uint128 => mapping(address => uint128)) public donorToTokenId;
    // Tracks crowdfund data
    // Mapping from crowdfundId to Crowdfund data
    mapping(uint128 => Crowdfund) public crowdfunds;
    // Tracks the amount donated by a donor to a crowdfund
    // Mapping from crowdfundId to donor address to amount donated
    mapping(uint128 => mapping(address => uint128)) public donations;
    // Track if a content ID hash has been used
    mapping(bytes32 => bool) public contentIdHashUsed;
    // Track if a donation ID hash has been used
    mapping(bytes32 => bool) public donationIdHashUsed;
    // Track donors per crowdfund for batch refund purposes
    mapping(uint128 => address[]) public uniqueDonorsList;
    // Track if a donor has been added to a crowdfund
    mapping(uint128 => mapping(address => bool)) public isDonorAdded;

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

    event ContractPaused();

    event ContractUnpaused();

    event NFTMinted(
        uint128 indexed crowdfundId,
        bytes32 indexed contentIdHash,
        address indexed donor,
        uint128 tokenId
    );

    // Admin events
    event BaseURIUpdated(string oldBaseURI, string newBaseURI);

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
        if (crowdfundId >= _crowdfundIdCounter || crowdfunds[crowdfundId].owner == address(0)) {
            revert CrowdfundDoesNotExist(crowdfundId);
        }
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
    ) ERC721("Farcaster Crowdfunds", "CROWDFUND") Ownable(initialOwner) {
        usdc = IERC20(_usdc);
        _baseMetadataURI = baseURI;
        maxDuration = _maxDuration > 0 ? _maxDuration : 7 days; // Default to 7 days if not specified
    }

    // ----- Receive and fallback functions -----

    /**
     * @dev Prevents ETH from being sent to non-existent functions or directly
     */
    fallback() external {
        revert FunctionNotFoundOrEthNotAccepted();
    }

    // ----- External state-changing functions -----

    /**
     * @notice Creates a new crowdfunding campaign.
     * @dev Requirements:
     *      - fundraisingTarget > 0
     *      - duration > 0 and <= maxDuration
     *      - if contentIdHash != bytes32(0), it must be unique
     * @param fundraisingTarget Amount in USDC (6-dec) to raise.
     * @param duration Duration in seconds for the crowdfund.
     * @param contentIdHash Optional bytes32 hash of the content ID; use bytes32(0) for none.
     * @return crowdfundId The ID of the newly created crowdfund.
     * @custom:reverts "Goal must be greater than 0" if fundraisingTarget is zero.
     * @custom:reverts "Duration must be greater than 0" if duration is zero.
     * @custom:reverts "Duration exceeds maximum allowed" if duration > maxDuration.
     * @custom:reverts "Content ID hash already used. Please use a unique hash or bytes32(0)." if contentIdHash is non-zero and already used.
     */
    function createCrowdfund(
        uint128 fundraisingTarget,
        uint64 duration,
        bytes32 contentIdHash
    ) external whenNotPaused returns (uint128 crowdfundId) {
        if (fundraisingTarget == 0) revert InvalidFundingTarget(fundraisingTarget);
        if (duration == 0) revert InvalidDuration(duration);
        if (duration > maxDuration) revert DurationExceedsMax(duration, maxDuration);

        // Check contentId uniqueness if not empty hash
        if (contentIdHash != bytes32(0)) {
            if (contentIdHashUsed[contentIdHash]) revert ContentIdHashAlreadyUsed(contentIdHash);
            contentIdHashUsed[contentIdHash] = true;
        }

        crowdfundId = _crowdfundIdCounter++;

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
     * @notice Donate USDC to a crowdfund and mint an NFT on first donation.
     * @dev Requirements:
     *      - amount > 0
     *      - crowdfund must exist, not ended, not cancelled
     *      - if donationIdHash != bytes32(0), it must be unique
     *      - tracks unique donors for batch refunds
     *      - first-time donors receive an NFT minted with _safeMint
     * @param crowdfundId The ID of the crowdfund to donate to.
     * @param donationIdHash Optional bytes32 hash of the donation ID; use bytes32(0) for none.
     * @param amount Amount of USDC (6-dec) to donate.
     * @custom:reverts "Amount must be greater than 0" if amount is zero.
     * @custom:reverts "Crowdfund has ended" if the crowdfund end time has passed.
     * @custom:reverts "Crowdfund has been cancelled" if the crowdfund is cancelled.
     * @custom:reverts "Donation ID hash already used. Please use a unique hash or bytes32(0)." if donationIdHash is non-zero and already used.
     */
    function donate(
        uint128 crowdfundId,
        bytes32 donationIdHash,
        uint128 amount
    ) external whenNotPaused crowdfundExists(crowdfundId) nonReentrant {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        if (amount == 0) revert AmountMustBeGreaterThanZero(amount);
        if (block.timestamp >= cf.endTimestamp) revert CrowdfundHasEnded(crowdfundId, cf.endTimestamp);
        if (cf.cancelled) revert ErrorCrowdfundCancelled(crowdfundId);

        // Check donationId uniqueness if not empty hash
        if (donationIdHash != bytes32(0)) {
            if (donationIdHashUsed[donationIdHash]) revert DonationIdHashAlreadyUsed(donationIdHash);
            donationIdHashUsed[donationIdHash] = true;
        }

        // Add donor to tracking only if they haven't been added before
        if (!isDonorAdded[crowdfundId][msg.sender]) {
            uniqueDonorsList[crowdfundId].push(msg.sender);
            isDonorAdded[crowdfundId][msg.sender] = true;
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
     * @notice Claim raised USDC if goal is met and campaign ended.
     * @dev Requirements:
     *      - caller must be the crowdfund owner
     *      - block.timestamp > endTimestamp
     *      - totalRaised >= goal
     *      - funds not already claimed and crowdfund not cancelled
     * @param crowdfundId ID of the crowdfund to claim.
     * @custom:reverts "Only the owner can claim funds" if caller is not owner.
     * @custom:reverts "Crowdfund not ended yet" if called before endTimestamp.
     * @custom:reverts "Goal not met" if totalRaised < goal.
     * @custom:reverts "Funds already claimed" if funds have already been claimed.
     * @custom:reverts "Crowdfund has been cancelled" if the crowdfund was cancelled.
     */
    function claimFunds(
        uint128 crowdfundId
    ) external whenNotPaused crowdfundExists(crowdfundId) nonReentrant {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        if (msg.sender != cf.owner) revert CrowdfundOwnerRequired(crowdfundId, msg.sender, cf.owner);
        if (block.timestamp <= cf.endTimestamp) revert CrowdfundNotEnded(crowdfundId, cf.endTimestamp);
        if (cf.totalRaised < cf.goal) revert GoalNotMet(crowdfundId, cf.goal, cf.totalRaised);
        if (cf.fundsClaimed) revert FundsAlreadyClaimed(crowdfundId);
        if (cf.cancelled) revert ErrorCrowdfundCancelled(crowdfundId);

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
     * @notice Claim refund of donated USDC if campaign failed or cancelled.
     * @dev Requirements:
     *      - campaign ended without meeting goal or was cancelled
     *      - funds not already claimed by owner
     *      - donor must have a non-zero donation
     * @param crowdfundId ID of the crowdfund to refund.
     * @custom:reverts "Refunds not available - goal met or crowdfund still active or cancelled" if conditions not met.
     * @custom:reverts "Funds already claimed by crowdfund creator" if owner has already claimed funds.
     * @custom:reverts "No donation to refund" if user has no donation.
     */
    function claimRefund(
        uint128 crowdfundId
    ) external whenNotPaused crowdfundExists(crowdfundId) nonReentrant {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        if (
            !(block.timestamp >= cf.endTimestamp && cf.totalRaised < cf.goal) &&
                !cf.cancelled
        ) {
            revert RefundsNotAvailable(crowdfundId);
        }
        if (cf.fundsClaimed) revert FundsAlreadyClaimedByOwner(crowdfundId);

        uint128 donationAmount = donations[crowdfundId][msg.sender];
        if (donationAmount == 0) revert NoDonationToRefund(crowdfundId, msg.sender);

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
     * @notice Cancel an active crowdfund to enable donor refunds.
     * @dev Requirements:
     *      - caller must be the crowdfund owner
     *      - funds not already claimed
     *      - crowdfund not already cancelled
     * @param crowdfundId ID of the crowdfund to cancel.
     * @custom:reverts "Not the crowdfund owner" if caller is not owner.
     * @custom:reverts "Funds already claimed" if funds have already been claimed.
     * @custom:reverts "Already cancelled" if crowdfund was already cancelled.
     */
    function cancelCrowdfund(
        uint128 crowdfundId
    ) external crowdfundExists(crowdfundId) {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        if (msg.sender != cf.owner) revert CrowdfundOwnerRequired(crowdfundId, msg.sender, cf.owner);
        if (cf.fundsClaimed) revert FundsAlreadyClaimed(crowdfundId);
        if (cf.cancelled) revert ErrorCrowdfundCancelled(crowdfundId);

        cf.cancelled = true;

        emit CrowdfundCancelled(crowdfundId, cf.contentIdHash, cf.owner);
    }

    /**
     * @notice Issue batch refunds for a failed crowdfund.
     * @dev Requirements:
     *      - block.timestamp >= endTimestamp
     *      - totalRaised < goal
     *      - !cancelled
     *      - !fundsClaimed
     *      - startIndex < uniqueDonorsList[crowdfundId].length
     * @param crowdfundId ID of the crowdfund to process refunds for.
     * @param startIndex Starting index in the unique donors list.
     * @param batchSize Number of donors to process in this batch.
     * @custom:reverts "Crowdfund has not ended yet" if before endTimestamp.
     * @custom:reverts "Crowdfund goal was met" if totalRaised >= goal.
     * @custom:reverts "Crowdfund was cancelled" if cancelled == true.
     * @custom:reverts "Funds already claimed by owner" if fundsClaimed == true.
     * @custom:reverts "Start index out of bounds" if startIndex >= donorsCount.
     */
    function pushRefunds(
        uint128 crowdfundId,
        uint256 startIndex,
        uint256 batchSize
    ) external whenNotPaused crowdfundExists(crowdfundId) nonReentrant {
        Crowdfund storage cf = crowdfunds[crowdfundId];

        // Check refund conditions: ended, goal not met, not cancelled, funds not claimed
        if (block.timestamp < cf.endTimestamp) revert CrowdfundNotEnded(crowdfundId, cf.endTimestamp);
        if (cf.totalRaised >= cf.goal) revert CrowdfundGoalWasMet(crowdfundId, cf.goal, cf.totalRaised);
        if (cf.cancelled) revert CrowdfundWasCancelled(crowdfundId);
        if (cf.fundsClaimed) revert FundsAlreadyClaimedByOwner(crowdfundId);

        address[] storage donors = uniqueDonorsList[crowdfundId];
        uint256 donorsCount = donors.length;

        // Validate batch parameters
        if (startIndex >= donorsCount) revert StartIndexOutOfBounds(startIndex, donorsCount);

        // Calculate the actual batch size (might be smaller than requested)
        uint256 endIndex = startIndex + batchSize;
        if (endIndex > donorsCount) {
            endIndex = donorsCount;
        }

        uint128 totalRefundedInBatch = 0;

        // Process refunds for the selected batch of donors
        for (uint256 i = startIndex; i < endIndex; i++) {
            address donor = donors[i];
            uint128 donationAmount = donations[crowdfundId][donor];

            if (donationAmount > 0) {
                // Reset donation amount first to prevent re-entrancy
                donations[crowdfundId][donor] = 0;
                totalRefundedInBatch += donationAmount;

                // Transfer USDC back to the donor
                usdc.safeTransfer(donor, donationAmount);

                emit RefundIssued(
                    crowdfundId,
                    cf.contentIdHash,
                    donor,
                    donationAmount
                );
            }
        }

        // Update the total raised amount accurately after processing all refunds in this call
        // This check ensures we don't underflow if the function somehow processed more than available.
        if (totalRefundedInBatch <= cf.totalRaised) {
            cf.totalRaised -= totalRefundedInBatch;
        } else {
            // Should be impossible given the donation checks, but safety first.
            cf.totalRaised = 0;
        }
    }

    // ----- Owner-only functions -----

    /**
     * @notice Update the base metadata URI used for NFT metadata URLs.
     * @dev Callable only by contract owner. Emits BaseURIUpdated(oldBaseURI, newBaseURI).
     * @param newBaseURI New base URI for metadata.
     * @custom:reverts if caller is not the contract owner.
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        string memory oldBaseURI = _baseMetadataURI;
        _baseMetadataURI = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI);
    }

    /**
     * @notice Set maximum allowed duration for new crowdfunds.
     * @dev Callable only by contract owner. Emits MaxDurationUpdated(oldMaxDuration, newMaxDuration, owner).
     *      Reverts if _maxDuration is zero.
     * @param _maxDuration New maximum duration in seconds.
     * @custom:reverts "Duration must be greater than 0" if _maxDuration is zero.
     * @custom:reverts if caller is not the contract owner.
     */
    function setMaxDuration(uint64 _maxDuration) external onlyOwner {
        if (_maxDuration == 0) revert InvalidDuration(_maxDuration);
        uint64 oldMaxDuration = maxDuration;
        maxDuration = _maxDuration;
        emit MaxDurationUpdated(oldMaxDuration, _maxDuration, msg.sender);
    }

    /**
     * @notice Rescue ERC20 tokens other than USDC from the contract.
     * @dev Callable only by contract owner. Uses SafeERC20.safeTransfer.
     *      Reverts if tokenAddress is the USDC token.
     * @param tokenAddress ERC20 token contract address to rescue.
     * @param to Recipient address for rescued tokens.
     * @param amount Amount of tokens to rescue.
     * @custom:reverts "Cannot withdraw USDC" if tokenAddress == usdc address.
     * @custom:reverts if caller is not the contract owner.
     */
    function rescueERC20(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (tokenAddress == address(usdc)) revert CannotWithdrawUSDC();
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(to, amount);
    }

    /**
     * @notice Pause all whenNotPaused-protected functions in the contract.
     * @dev Callable only by contract owner. Emits ContractPaused event.
     * @custom:reverts if caller is not the contract owner.
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused();
    }

    /**
     * @notice Unpause the contract, re-enabling whenNotPaused-protected functions.
     * @dev Callable only by contract owner. Emits ContractUnpaused event.
     * @custom:reverts if caller is not the contract owner.
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused();
    }

    // ----- External view functions -----

    /**
     * @notice Get the total number of unique donors for a crowdfund.
     * @dev Reads the length of uniqueDonorsList for the given crowdfund.
     * @param crowdfundId ID of the crowdfund.
     * @return count The number of unique donors.
     * @custom:reverts "Crowdfund does not exist" if the crowdfundId is invalid.
     */
    function getDonorsCount(
        uint128 crowdfundId
    ) external view returns (uint256) {
        return uniqueDonorsList[crowdfundId].length;
    }

    /**
     * @notice Get refund statistics for a failed crowdfund.
     * @dev Iterates through unique donors to count pending refunds and sum amounts.
     * @param crowdfundId ID of the crowdfund.
     * @return totalDonors Total number of unique donors.
     * @return pendingRefunds Number of donors with pending refunds.
     * @return totalPendingAmount Total amount of USDC pending refund.
     * @custom:reverts "Crowdfund does not exist" if the crowdfundId is invalid.
     */
    function getCrowdfundRefundInfo(
        uint128 crowdfundId
    )
        external
        view
        crowdfundExists(crowdfundId)
        returns (
            uint256 totalDonors,
            uint256 pendingRefunds,
            uint128 totalPendingAmount
        )
    {
        address[] storage donors = uniqueDonorsList[crowdfundId];
        totalDonors = donors.length;

        pendingRefunds = 0;
        totalPendingAmount = 0;

        for (uint256 i = 0; i < totalDonors; i++) {
            uint128 donationAmount = donations[crowdfundId][donors[i]];
            if (donationAmount > 0) {
                pendingRefunds++;
                totalPendingAmount += donationAmount;
            }
        }

        return (totalDonors, pendingRefunds, totalPendingAmount);
    }

    /**
     * @notice Fetch detailed donation information for a given user.
     * @dev Scans all crowdfunds up to _crowdfundIdCounter to assemble per-crowdfund data; arrays align by index.
     * @param user Address of the donor to query.
     * @return crowdfundIds Array of crowdfund IDs the user has donated to.
     * @return amounts Array of amounts donated per crowdfund.
     * @return isActive Array of booleans indicating if each crowdfund is still active (not ended or cancelled).
     * @return goalMet Array of booleans indicating if each crowdfund met its funding goal.
     * @return endTimestamps Array of end timestamps for each crowdfund.
     * @return totalDonated Sum of all donations made by the user.
     */
    function getUserDonationsDetail(
        address user
    )
        external
        view
        returns (
            uint128[] memory crowdfundIds,
            uint128[] memory amounts,
            bool[] memory isActive,
            bool[] memory goalMet,
            uint64[] memory endTimestamps,
            uint128 totalDonated
        )
    {
        // Count valid donations first
        uint count = 0;
        totalDonated = 0;

        for (uint128 i = 0; i < _crowdfundIdCounter; i++) {
            if (donations[i][user] > 0) {
                count++;
                totalDonated += donations[i][user];
            }
        }

        // Create arrays of exact size needed
        crowdfundIds = new uint128[](count);
        amounts = new uint128[](count);
        isActive = new bool[](count);
        goalMet = new bool[](count);
        endTimestamps = new uint64[](count);

        // Fill arrays
        uint index = 0;
        for (uint128 i = 0; i < _crowdfundIdCounter; i++) {
            uint128 amount = donations[i][user];
            if (amount > 0) {
                Crowdfund storage cf = crowdfunds[i];

                crowdfundIds[index] = i;
                amounts[index] = amount;
                isActive[index] =
                    !cf.cancelled &&
                    block.timestamp < cf.endTimestamp;
                goalMet[index] = cf.totalRaised >= cf.goal;
                endTimestamps[index] = cf.endTimestamp;

                index++;
            }
        }
    }

    // ----- Public view functions -----

    /**
     * @notice Returns the metadata URI for a donation NFT.
     * @dev URI is baseURI concatenated with the crowdfund ID of the token. Reverts if token does not exist.
     * @param tokenId ID of the NFT token.
     * @return A string representing the token URI.
     * @custom:reverts "Token does not exist" if _ownerOf(tokenId) == address(0).
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // Ensure the token exists before proceeding
        if (_ownerOf(tokenId) == address(0)) {
            revert TokenDoesNotExist(tokenId); // Pass tokenId here
        }

        uint128 crowdfundId = tokenToCrowdfund[tokenId];

        return
            string(
                abi.encodePacked(
                    _baseMetadataURI,
                    toString(crowdfundId)
                )
            );
    }

    // ----- Internal functions -----

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
