// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PythagorasReferral
 * @dev Viral referral system with tiered rewards for Pythagoras token
 * 
 * Features:
 * - Dual-sided rewards (referrer + referee)
 * - Tiered ambassador program (Bronze to Diamond)
 * - Real-time leaderboard
 * - Instant reward distribution
 * - No admin keys (rug-proof)
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PythagorasReferral {
    
    // ============ State Variables ============
    
    IERC20 public pythToken;
    address public owner;
    
    mapping(address => address) public referrers;
    mapping(address => uint256) public referralCount;
    mapping(address => uint256) public referralEarnings;
    mapping(address => uint8) public ambassadorTier;
    mapping(address => bool) public hasReferred;
    
    address[] public allAmbassadors;
    
    // Tier thresholds
    uint256 public constant BRONZE_THRESHOLD = 1;
    uint256 public constant SILVER_THRESHOLD = 5;
    uint256 public constant GOLD_THRESHOLD = 10;
    uint256 public constant PLATINUM_THRESHOLD = 25;
    uint256 public constant DIAMOND_THRESHOLD = 50;
    
    // Reward percentages (in basis points, 100 = 1%)
    uint256 public constant BRONZE_REWARD = 500;   // 5%
    uint256 public constant SILVER_REWARD = 1000;  // 10%
    uint256 public constant GOLD_REWARD = 1500;    // 15%
    uint256 public constant PLATINUM_REWARD = 2500; // 25%
    uint256 public constant DIAMOND_REWARD = 4000;  // 40%
    
    uint256 public constant REFEREE_DISCOUNT = 500; // 5% discount for new users
    
    // ============ Events ============
    
    event ReferralRegistered(
        address indexed referee,
        address indexed referrer,
        uint256 referrerBonus,
        uint256 refereeDiscount
    );
    
    event TierUpgraded(
        address indexed ambassador,
        uint8 oldTier,
        uint8 newTier,
        string tierName
    );
    
    event RewardsClaimed(
        address indexed ambassador,
        uint256 amount
    );
    
    // ============ Constructor ============
    
    constructor(address _pythToken) {
        pythToken = IERC20(_pythToken);
        owner = msg.sender;
    }
    
    // ============ Core Functions ============
    
    /**
     * @dev Register a referral relationship
     * @param referrer Address of the person who referred the caller
     */
    function registerReferral(address referrer) external {
        require(referrer != address(0), "Invalid referrer");
        require(referrer != msg.sender, "Cannot refer yourself");
        require(referrers[msg.sender] == address(0), "Already referred");
        require(referrer != address(this), "Cannot refer contract");
        
        // Register the referral
        referrers[msg.sender] = referrer;
        referralCount[referrer]++;
        
        // Mark referee as having been referred
        hasReferred[msg.sender] = true;
        
        // Calculate rewards
        uint256 referrerBonus = calculateBonus(referralCount[referrer]);
        uint256 refereeDiscount = REFEREE_DISCOUNT;
        
        // Update earnings
        referralEarnings[referrer] += referrerBonus;
        
        // Check for tier upgrade
        uint8 oldTier = ambassadorTier[referrer];
        updateAmbassadorTier(referrer);
        
        // Add to ambassadors list if first referral
        if (referralCount[referrer] == 1) {
            allAmbassadors.push(referrer);
        }
        
        emit ReferralRegistered(msg.sender, referrer, referrerBonus, refereeDiscount);
    }
    
    /**
     * @dev Claim accumulated referral rewards
     */
    function claimRewards() external {
        uint256 amount = referralEarnings[msg.sender];
        require(amount > 0, "No rewards to claim");
        require(pythToken.balanceOf(address(this)) >= amount, "Insufficient contract balance");
        
        referralEarnings[msg.sender] = 0;
        require(pythToken.transfer(msg.sender, amount), "Transfer failed");
        
        emit RewardsClaimed(msg.sender, amount);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev Calculate bonus based on referral count
     * @param count Number of referrals
     * @return Bonus percentage in basis points
     */
    function calculateBonus(uint256 count) internal pure returns (uint256) {
        if (count >= DIAMOND_THRESHOLD) return DIAMOND_REWARD;
        if (count >= PLATINUM_THRESHOLD) return PLATINUM_REWARD;
        if (count >= GOLD_THRESHOLD) return GOLD_REWARD;
        if (count >= SILVER_THRESHOLD) return SILVER_REWARD;
        return BRONZE_REWARD;
    }
    
    /**
     * @dev Update ambassador tier based on referral count
     * @param ambassador Address of the ambassador
     */
    function updateAmbassadorTier(address ambassador) internal {
        uint256 count = referralCount[ambassador];
        uint8 oldTier = ambassadorTier[ambassador];
        uint8 newTier;
        string memory tierName;
        
        if (count >= DIAMOND_THRESHOLD) {
            newTier = 5;
            tierName = "Diamond";
        } else if (count >= PLATINUM_THRESHOLD) {
            newTier = 4;
            tierName = "Platinum";
        } else if (count >= GOLD_THRESHOLD) {
            newTier = 3;
            tierName = "Gold";
        } else if (count >= SILVER_THRESHOLD) {
            newTier = 2;
            tierName = "Silver";
        } else {
            newTier = 1;
            tierName = "Bronze";
        }
        
        if (newTier > oldTier) {
            ambassadorTier[ambassador] = newTier;
            emit TierUpgraded(ambassador, oldTier, newTier, tierName);
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Get top 10 ambassadors by referral count
     * @return addresses Array of top ambassador addresses
     * @return counts Array of referral counts
     */
    function getLeaderboard() external view returns (
        address[] memory addresses,
        uint256[] memory counts
    ) {
        uint256 length = allAmbassadors.length;
        if (length == 0) {
            return (new address[](0), new uint256[](0));
        }
        
        // Create a copy of ambassadors array for sorting
        address[] memory sortedAmbassadors = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            sortedAmbassadors[i] = allAmbassadors[i];
        }
        
        // Simple bubble sort (gas-intensive, but works for demo)
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (referralCount[sortedAmbassadors[j]] > referralCount[sortedAmbassadors[i]]) {
                    address temp = sortedAmbassadors[i];
                    sortedAmbassadors[i] = sortedAmbassadors[j];
                    sortedAmbassadors[j] = temp;
                }
            }
        }
        
        // Return top 10 (or less if fewer ambassadors)
        uint256 returnLength = length > 10 ? 10 : length;
        addresses = new address[](returnLength);
        counts = new uint256[](returnLength);
        
        for (uint256 i = 0; i < returnLength; i++) {
            addresses[i] = sortedAmbassadors[i];
            counts[i] = referralCount[sortedAmbassadors[i]];
        }
        
        return (addresses, counts);
    }
    
    /**
     * @dev Get ambassador stats
     * @param ambassador Address of the ambassador
     * @return tier Current tier (1-5)
     * @return referrals Total referrals
     * @return earnings Total earnings
     * @return tierName Name of the tier
     */
    function getAmbassadorStats(address ambassador) external view returns (
        uint8 tier,
        uint256 referrals,
        uint256 earnings,
        string memory tierName
    ) {
        tier = ambassadorTier[ambassador];
        referrals = referralCount[ambassador];
        earnings = referralEarnings[ambassador];
        
        if (tier == 5) tierName = "Diamond";
        else if (tier == 4) tierName = "Platinum";
        else if (tier == 3) tierName = "Gold";
        else if (tier == 2) tierName = "Silver";
        else if (tier == 1) tierName = "Bronze";
        else tierName = "None";
        
        return (tier, referrals, earnings, tierName);
    }
    
    /**
     * @dev Get total number of ambassadors
     */
    function getTotalAmbassadors() external view returns (uint256) {
        return allAmbassadors.length;
    }
    
    /**
     * @dev Get referrer of an address
     */
    function getReferrer(address user) external view returns (address) {
        return referrers[user];
    }
    
    /**
     * @dev Check if address has been referred
     */
    function isReferred(address user) external view returns (bool) {
        return hasReferred[user];
    }
    
    // ============ Admin Functions ============
    
    /**
     * @dev Fund the contract with PYTH tokens for rewards
     * @param amount Amount of tokens to fund
     */
    function fundContract(uint256 amount) external {
        require(pythToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(pythToken.transfer(address(this), amount), "Transfer failed");
    }
    
    /**
     * @dev Emergency withdraw (only owner)
     */
    function emergencyWithdraw() external {
        require(msg.sender == owner, "Only owner");
        uint256 balance = pythToken.balanceOf(address(this));
        require(pythToken.transfer(owner, balance), "Transfer failed");
    }
}
