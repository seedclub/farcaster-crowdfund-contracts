// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";

contract DeployBase is Script {
    // Base Mainnet USDC address
    address public constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // Base URI for NFT metadata
    string public constant BASE_URI = "https://crowdfund.seedclub.com/crowdfund/";
    
    // Maximum crowdfund duration (14 days)
    uint64 public constant MAX_DURATION = 14 days;

    function run() public {
        // Retrieve deployer private key from env variable
        uint256 deployerPrivateKey = vm.envUint("SEEDCLUB_PRIV_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployerAddress);
        console.log("Deploying FarcasterCrowdfund to Base Mainnet...");
        
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
