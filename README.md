# Farcaster Crowdfund

A decentralized crowdfunding platform built for the Farcaster ecosystem, allowing users to create and contribute to crowdfunding campaigns with NFT rewards for donors.

**Documentation & Prototypes**

* [PRD (Product Requirements Document)](https://docs.google.com/document/d/1pKOuC1SWLjoGwhF4qI1B0T2kpM9mQ1MNSxJ1shnZWqI/edit?usp=sharing)
* [v0 Mock‑up](https://v0-farcaster-fundraise.vercel.app/)

## Overview

Farcaster Crowdfund is a mini‑app built on Farcaster Frames that enables users to …

* Create crowdfunding campaigns with custom goals, descriptions, and images
* Donate USDC to campaigns and automatically receive an NFT
* Share campaigns through Farcaster cast intents
* Receive notifications about campaign updates
* Claim funds as creators of successful campaigns
* Claim refunds for unsuccessful campaigns

## Repository Structure

```text
farcaster-crowdfund/
├── src/
│   └── FarcasterCrowdfund.sol      # main contract
├── test/
│   ├── Base_FarcasterCrowdfund.t.sol   # shared fixture
│   ├── Create.t.sol, Donate.t.sol …    # feature‑group tests
│   ├── FarcasterCrowdfund_EdgeFuzz.t.sol # gap‑coverage & fuzz
│   ├── Invariants.t.sol                 # long‑running invariants
│   └── mocks/
│       ├── MockERC20.sol
│       └── GrumpyToken.sol          # ERC‑20 that can revert
├── script/
│   ├── DeployBase.s.sol            # Base main‑net
│   └── DeployBaseSepolia.s.sol     # Base Sepolia
├── frontend/                        # React front‑end (frames)
├── api/                             # Back‑end helpers
├── .env.example
├── foundry.toml
└── README.md



⸻

Smart Contract Highlights
	•	ERC‑721 NFTs for donors (tokenURI points to campaign‑id)
	•	USDC‑denominated crowdfunding with goal / deadline
	•	Automatic refunds or creator claims
	•	“Batch‑push” refunds to reduce donor gas
	•	Emergency pause() switch
	•	Written in Solidity 0.8.19, fully checked with ReentrancyGuard

⸻

Prerequisites
	•	Foundry tool‑chain
	•	Node.js ≥ 16 (LTS) for the front‑end
	•	An Ethereum wallet (private key) with ETH on Base (or Base Sepolia)
	•	USDC on the target chain for realistic testing

⸻

Setup

git clone https://github.com/seedclub/farcaster-crowdfund.git
cd farcaster-crowdfund

forge install                  # solidity dependencies
cd frontend && npm install && cd ..

Create a local env‑file and set keys:

cp .env.example .env

#  used by forge script … --private-key
export BASE_PRIV_KEY=0xYOUR_PRIVATE_KEY

#  used by forge script … --etherscan-api-key
export BASESCAN_API_KEY=YourBaseScanKey



⸻

Testing

forge test -vvv                     # all contracts
forge test --match-contract Donate  # only Donate.t.sol

Coverage run

forge coverage -vvv
genhtml lcov.info --output-directory coverage
open coverage/index.html            # on macOS

Gas-tight compile

forge test -vvv


⸻

Deployment

We always compile scripts with the prod profile to keep byte‑code identical to main‑net expectations.

Deploy to Base Sepolia

forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia \
  --rpc-url       https://sepolia.base.org \
  --broadcast --verify \
  --private-key   $GOERLI_PRIV_KEY \
  --etherscan-api-key $BASESCAN_API_KEY

Deploy to Base Main‑net

forge script script/DeployBase.s.sol:DeployBase \
  --rpc-url       https://mainnet.base.org \
  --broadcast --verify \
  --private-key   $SEEDCLUB_PRIV_KEY \
  --etherscan-api-key $BASESCAN_API_KEY



⸻

Important Addresses

network	USDC address
Base Main‑net	0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Base Sepolia	0x036CbD53842c5426634e7929541eC2318f3dCF7e (verify)



⸻

Contract Configuration
	•	ERC‑721 Name: “Farcaster Crowdfund”
	•	Symbol: “CROWDFUND”
	•	Max crowdfund duration: 7 days (owner‑configurable)
	•	Base URI: owner‑configurable for metadata

Owner helper — update base URI

cast send --private-key $BASE_PRIV_KEY \
  --rpc-url https://mainnet.base.org \
  <CONTRACT_ADDRESS> \
  "setBaseURI(string)" \
  "https://new‑metadata‑url.com/nfts/"



⸻

NFT Metadata Convention

{baseURI}/{crowdfundId}/{tokenId}

Example (JSON):

{
  "name": "Farcaster Crowdfund #42",
  "description": "Contribution to 'Rent karaoke room for FarCon 2025'",
  "image": "https://crowdfund.seedclub.com/images/42.png",
  "attributes": [
    { "trait_type": "Crowdfund",     "value": "Rent karaoke room for FarCon 2025" },
    { "trait_type": "Contributor",   "value": "0x1234…" },
    { "trait_type": "Contribution Date", "value": "2025‑04‑01" }
  ]
}



⸻

License
MIT