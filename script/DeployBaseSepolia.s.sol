// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";

contract DeployBaseSepolia is Script {
    // Base Sepolia Testnet USDC address
    address public constant USDC_ADDRESS = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Update this if needed
    
    // Base URI for NFT metadata
    string public constant BASE_URI = "https://crowdfund.seedclub.com/crowdfund/";
    
    // Maximum crowdfund duration (7 days)
    uint64 public constant MAX_DURATION = 7 days;

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
