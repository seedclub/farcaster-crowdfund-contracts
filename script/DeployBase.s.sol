// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {FarcasterCrowdfund} from "../src/FarcasterCrowdfund.sol";

contract DeployBase is Script {
    // Base Mainnet USDC address
    address public constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // Base URI for NFT metadata
    string public constant BASE_URI = "https://crowdfund.seedclub.com/nfts/";
    
    // Maximum crowdfund duration (7 days)
    uint256 public constant MAX_DURATION = 7 days;

    function run() public {
        // Retrieve deployer private key from env variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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
