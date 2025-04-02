# Farcaster Crowdfund

A decentralized crowdfunding platform built for the Farcaster ecosystem, allowing users to create and contribute to crowdfunding campaigns with NFT rewards for donors.

**Documentation & Prototypes:**
- [PRD (Product Requirements Document)](https://docs.google.com/document/d/1pKOuC1SWLjoGwhF4qI1B0T2kpM9mQ1MNSxJ1shnZWqI/edit?tab=t.0)
- [v0 Mockup](https://v0-farcaster-fundraise.vercel.app/)

## Overview

Farcaster Crowdfund is a mini-app built on Farcaster Frames that enables users to:

- Create crowdfunding campaigns with custom goals, descriptions, and images
- Donate USDC to campaigns and automatically receive an NFT
- Share campaigns through Farcaster cast intents
- Receive notifications about campaign updates
- Claim funds as creators of successful campaigns
- Claim refunds for unsuccessful campaigns

## Repository Structure

```
farcaster-crowdfund/
├── src/                       # Smart contract source files
│   └── FarcasterCrowdfund.sol # Main contract implementation
├── test/                      # Test files
│   ├── FarcasterCrowdfund.t.sol # Main contract tests
│   └── mocks/                 # Mock contracts for testing
│       └── MockERC20.sol      # Mock USDC implementation
├── script/                    # Deployment scripts
│   ├── DeployBase.s.sol       # Base Mainnet deployment
│   └── DeployBaseSepolia.s.sol # Base Sepolia deployment
├── frontend/                  # Frontend code (React)
├── api/                       # Backend API code
├── .env.example               # Example environment variables
├── foundry.toml               # Foundry configuration
└── README.md                  # Project documentation
```

## Smart Contract

The `FarcasterCrowdfund` contract provides the core functionality for the platform:

- ERC721-compliant NFT minting for donors
- USDC-based crowdfunding
- Automatic NFT issuance upon donation
- Farcaster ID integration
- Built-in refund mechanisms
- Emergency pause functionality

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) for smart contract development
- [Node.js](https://nodejs.org/) (v16+) for frontend development
- An Ethereum wallet with private key access
- ETH on Base or Base Sepolia for contract deployment

## Setup

1. Clone the repository:

```bash
git clone https://github.com/seedclub/farcaster-crowdfund.git
cd farcaster-crowdfund
```

2. Install dependencies:

```bash
forge install
cd frontend && npm install && cd ..
```

3. Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

4. Edit the `.env` file with your private key and other configuration:

```
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_basescan_api_key
```

## Testing

Run the contract tests:

```bash
forge test -vvv
```

For specific test files:

```bash
forge test --match-path test/FarcasterCrowdfund.t.sol -vvv
```

For gas reporting:

```bash
forge test --gas-report
```

## Deployment

### Deploy to Base Sepolia Testnet

```bash
source .env
forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia --rpc-url https://sepolia.base.org --broadcast --verify
```

### Deploy to Base Mainnet

```bash
source .env
forge script script/DeployBase.s.sol:DeployBase --rpc-url https://mainnet.base.org --broadcast --verify
```

## Important Addresses

- Base Mainnet USDC: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Base Sepolia USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e` (verify this address)

## Contract Configuration

The deployed contract has the following configuration:

- ERC721 Name: "Farcaster Crowdfund"
- ERC721 Symbol: "CROWDFUND"
- Maximum Crowdfund Duration: 7 days (configurable by owner)
- Base URI: Configurable base URL for NFT metadata

## Owner Functions

As the contract owner, you can:

1. Change the base URI for NFT metadata
2. Update the maximum allowed duration for crowdfunds
3. Pause the creation of new crowdfunds

Example of updating the base URI:

```bash
cast send --private-key $PRIVATE_KEY \
  --rpc-url https://mainnet.base.org \
  <CONTRACT_ADDRESS> \
  "setBaseURI(string)" \
  "https://new-metadata-url.com/nfts/"
```

## NFT Metadata

The contract expects NFT metadata to be served from:

```
{baseURI}/{crowdfundId}/{tokenId}
```

Example metadata format:

```json
{
  "name": "Farcaster Crowdfund #42",
  "description": "Contribution to 'Rent karaoke room for Farcon 2025'",
  "image": "https://crowdfund.seedclub.com/images/42.png",
  "attributes": [
    {
      "trait_type": "Crowdfund",
      "value": "Rent karaoke room for Farcon 2025"
    },
    {
      "trait_type": "Contributor",
      "value": "0x1234..."
    },
    {
      "trait_type": "Contribution Date",
      "value": "2025-04-01"
    }
  ]
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.