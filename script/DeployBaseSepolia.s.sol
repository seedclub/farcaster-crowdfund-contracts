// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";

contract DeployBaseSepolia is Script {
    // Base Sepolia Testnet USDC address
    // This is the USDC address on Base Sepolia - if USDC is not available,
    // you may need to deploy a mock USDC token or use a different stablecoin
    address public constant USDC_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Update this if needed
    
    // Base URI for NFT metadata
    string public constant BASE_URI = "https://test.crowdfund.seedclub.com/nfts/";
    
    // Maximum crowdfund duration (7 days)
    uint256 public constant MAX_DURATION = 7 days;

    function run() public {
        // Retrieve deployer private key from env variable
        uint256 deployerPrivateKey = vm.envUint("GOERLI_PRIV_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployerAddress);
        console.log("Deploying FarcasterCrowdfund to Base Sepolia Testnet...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the FarcasterCrowdfund contract
        FarcasterCrowdfund crowdfund = new FarcasterCrowdfund(
            USDC_ADDRESS,
            deployerAddress, // initialOwner
            BASE_URI,
            MAX_DURATION
        );
        
        vm.stopBroadcast();
        
        console.log("FarcasterCrowdfund deployed at:", address(crowdfund));
    }
}
