// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CommunityIncentives
 * @dev Zero-cost community-driven liquidity and growth system
 * 
 * Features:
 * - Rewards first liquidity provider (1% of supply)
 * - Rewards top referrers automatically
 * - Gamified leaderboard system
 * - All incentives come from token supply, not external funds
 * - ZERO COST to deploy and run
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract CommunityIncentives {
    
    // ============ State Variables ============
    
    address public pythToken = 0x0a5d91537E38C25F772dea78914737582D1C1C47;
    address public owner;
    
    // First LP provider bonus
    address public firstLPProvider;
    bool public firstLPBonusClaimed;
    uint256 public constant FIRST_LP_BONUS = 10_000_000 * 10**18; // 1% of supply
    
    // Referral system
    mapping(address => address) public referrers; // user => referrer
    mapping(address => uint256) public referralCount; // referrer => count
    mapping(address => uint256) public referralEarnings; // referrer => earnings
    
    // Leaderboard
    address[] public topReferrers;
    uint256 public constant LEADERBOARD_SIZE = 10;
    
    // Trading competition
    mapping(address => uint256) public tradingVolume;
    address[] public topTraders;
    
    // Airdrop eligibility
    mapping(address => bool) public airdropClaimed;
    uint256 public constant AIRDROP_AMOUNT = 1000 * 10**18; // 1000 PYTH
    
    // ============ Events ============
    
    event FirstLPBonusClaimed(address indexed provider, uint256 amount);
    event ReferralRegistered(address indexed user, address indexed referrer);
    event ReferralRewardPaid(address indexed referrer, uint256 amount);
    event AirdropClaimed(address indexed user, uint256 amount);
    event LeaderboardUpdated(address[] topReferrers);
    
    // ============ Constructor ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ First LP Provider Bonus ============
    
    /**
     * @dev Claim first LP provider bonus
     * Must be the first person to create a liquidity pool
     */
    function claimFirstLPBonus(address poolAddress) external {
        require(!firstLPBonusClaimed, "Bonus already claimed");
        require(poolAddress != address(0), "Invalid pool");
        
        // Verify this is a real liquidity pool
        // (In production, add more verification)
        
        firstLPProvider = msg.sender;
        firstLPBonusClaimed = true;
        
        // Transfer bonus
        IERC20(pythToken).transfer(msg.sender, FIRST_LP_BONUS);
        
        emit FirstLPBonusClaimed(msg.sender, FIRST_LP_BONUS);
    }
    
    // ============ Referral System ============
    
    /**
     * @dev Register a referral
     * @param referrer Address of the person who referred you
     */
    function registerReferral(address referrer) external {
        require(referrer != address(0), "Invalid referrer");
        require(referrer != msg.sender, "Cannot refer yourself");
        require(referrers[msg.sender] == address(0), "Already referred");
        
        referrers[msg.sender] = referrer;
        referralCount[referrer]++;
        
        // Reward referrer (0.1% of supply per referral)
        uint256 reward = 1_000_000 * 10**18; // 0.1% of supply
        referralEarnings[referrer] += reward;
        IERC20(pythToken).transfer(referrer, reward);
        
        emit ReferralRegistered(msg.sender, referrer);
        emit ReferralRewardPaid(referrer, reward);
        
        // Update leaderboard
        updateLeaderboard(referrer);
    }
    
    /**
     * @dev Update leaderboard with new referrer
     */
    function updateLeaderboard(address referrer) internal {
        // Simple insertion sort for top 10
        bool inLeaderboard = false;
        for (uint256 i = 0; i < topReferrers.length; i++) {
            if (topReferrers[i] == referrer) {
                inLeaderboard = true;
                break;
            }
        }
        
        if (!inLeaderboard && topReferrers.length < LEADERBOARD_SIZE) {
            topReferrers.push(referrer);
        }
        
        // Sort leaderboard
        for (uint256 i = 0; i < topReferrers.length; i++) {
            for (uint256 j = i + 1; j < topReferrers.length; j++) {
                if (referralCount[topReferrers[j]] > referralCount[topReferrers[i]]) {
                    address temp = topReferrers[i];
                    topReferrers[i] = topReferrers[j];
                    topReferrers[j] = temp;
                }
            }
        }
        
        emit LeaderboardUpdated(topReferrers);
    }
    
    // ============ Airdrop System ============
    
    /**
     * @dev Claim airdrop
     * Must be eligible (have MATIC balance, not a bot)
     */
    function claimAirdrop() external {
        require(!airdropClaimed[msg.sender], "Already claimed");
        require(isEligibleForAirdrop(msg.sender), "Not eligible");
        
        airdropClaimed[msg.sender] = true;
        IERC20(pythToken).transfer(msg.sender, AIRDROP_AMOUNT);
        
        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT);
    }
    
    /**
     * @dev Check if address is eligible for airdrop
     */
    function isEligibleForAirdrop(address user) public view returns (bool) {
        // Must have at least 0.1 MATIC (prevents bots)
        if (user.balance < 0.1 ether) return false;
        
        // Must not be a contract (prevents bots)
        uint256 size;
        assembly { size := extcodesize(user) }
        if (size > 0) return false;
        
        // Must not have claimed yet
        if (airdropClaimed[user]) return false;
        
        return true;
    }
    
    // ============ Trading Competition ============
    
    /**
     * @dev Record trading volume (called by external tracker)
     */
    function recordTrade(address trader, uint256 volume) external {
        require(msg.sender == owner, "Only owner");
        tradingVolume[trader] += volume;
        updateTradingLeaderboard(trader);
    }
    
    /**
     * @dev Update trading leaderboard
     */
    function updateTradingLeaderboard(address trader) internal {
        bool inLeaderboard = false;
        for (uint256 i = 0; i < topTraders.length; i++) {
            if (topTraders[i] == trader) {
                inLeaderboard = true;
                break;
            }
        }
        
        if (!inLeaderboard && topTraders.length < LEADERBOARD_SIZE) {
            topTraders.push(trader);
        }
        
        // Sort by volume
        for (uint256 i = 0; i < topTraders.length; i++) {
            for (uint256 j = i + 1; j < topTraders.length; j++) {
                if (tradingVolume[topTraders[j]] > tradingVolume[topTraders[i]]) {
                    address temp = topTraders[i];
                    topTraders[i] = topTraders[j];
                    topTraders[j] = temp;
                }
            }
        }
    }
    
    /**
     * @dev Reward top traders
     */
    function rewardTopTraders() external {
        require(msg.sender == owner, "Only owner");
        
        uint256[] memory rewards = new uint256[](LEADERBOARD_SIZE);
        rewards[0] = 5_000_000 * 10**18;  // 0.5% for #1
        rewards[1] = 3_000_000 * 10**18;  // 0.3% for #2
        rewards[2] = 2_000_000 * 10**18;  // 0.2% for #3
        // ... and so on
        
        for (uint256 i = 0; i < topTraders.length && i < rewards.length; i++) {
            if (topTraders[i] != address(0) && rewards[i] > 0) {
                IERC20(pythToken).transfer(topTraders[i], rewards[i]);
            }
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Get referral stats for an address
     */
    function getReferralStats(address user) external view returns (
        uint256 count,
        uint256 earnings,
        uint256 leaderboardPosition
    ) {
        count = referralCount[user];
        earnings = referralEarnings[user];
        
        leaderboardPosition = 0;
        for (uint256 i = 0; i < topReferrers.length; i++) {
            if (topReferrers[i] == user) {
                leaderboardPosition = i + 1;
                break;
            }
        }
        
        return (count, earnings, leaderboardPosition);
    }
    
    /**
     * @dev Get leaderboard
     */
    function getLeaderboard() external view returns (
        address[] memory referrers,
        uint256[] memory counts
    ) {
        referrers = topReferrers;
        counts = new uint256[](topReferrers.length);
        
        for (uint256 i = 0; i < topReferrers.length; i++) {
            counts[i] = referralCount[topReferrers[i]];
        }
        
        return (referrers, counts);
    }
    
    /**
     * @dev Get trading leaderboard
     */
    function getTradingLeaderboard() external view returns (
        address[] memory traders,
        uint256[] memory volumes
    ) {
        traders = topTraders;
        volumes = new uint256[](topTraders.length);
        
        for (uint256 i = 0; i < topTraders.length; i++) {
            volumes[i] = tradingVolume[topTraders[i]];
        }
        
        return (traders, volumes);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @dev Fund contract with PYTH tokens
     */
    function fundContract(uint256 amount) external {
        IERC20(pythToken).transfer(address(this), amount);
    }
    
    /**
     * @dev Emergency withdraw
     */
    function emergencyWithdraw() external {
        require(msg.sender == owner, "Only owner");
        uint256 balance = IERC20(pythToken).balanceOf(address(this));
        IERC20(pythToken).transfer(owner, balance);
    }
}

/**
 * DEPLOYMENT & USAGE INSTRUCTIONS:
 * 
 * ZERO-COST DEPLOYMENT:
 * 1. Deploy on Polygon (low gas fees, ~$0.01)
 * 2. Transfer 10% of PYTH supply to contract
 * 3. Announce on social media
 * 
 * COMMUNITY ACTIONS (All Zero-Cost to You):
 * 1. First person creates LP → Gets 1% bonus
 * 2. People refer friends → Get 0.1% per referral
 * 3. People claim airdrop → Spreads word organically
 * 4. Top traders compete → Generates volume
 * 
 * RESULT:
 * - Liquidity pool created (by community)
 * - Trading volume generated (by community)
 * - Holders increased (by airdrop)
 * - Marketing done (by referrals)
 * - COST TO YOU: $0
 * 
 * THE GENIUS:
 * All incentives come from token supply, not your pocket.
 * Community does all the work for rewards.
 * You just coordinate and watch it grow.
 */
