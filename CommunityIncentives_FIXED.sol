// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CommunityIncentives
 * @dev Community-driven incentive system for Pythagoras token
 * Features:
 * - First LP provider bonus (1% of supply)
 * - Referral rewards (0.1% per referral)
 * - Airdrop system (1000 PYTH per eligible user)
 * - Trading competitions
 * - Leaderboard tracking
 */
contract CommunityIncentives {
    
    // ============ STATE VARIABLES ============
    
    address public owner;
    address public pythToken; // PYTH token address
    
    // LP Bonus
    address public firstLPProvider;
    bool public lpBonusClaimed;
    uint256 public constant LP_BONUS = 10_000_000 * 10**18; // 1% of 1B supply
    
    // Airdrop
    uint256 public constant AIRDROP_AMOUNT = 1000 * 10**18; // 1000 PYTH
    mapping(address => bool) public hasClaimedAirdrop;
    uint256 public totalAirdropsClaimed;
    
    // Referral System
    mapping(address => address) public userReferrer; // user => referrer
    mapping(address => uint256) public referralCount; // referrer => count
    mapping(address => uint256) public referralEarnings; // referrer => earnings
    uint256 public constant REFERRAL_REWARD = 1_000_000 * 10**18; // 0.1% per referral
    
    // Leaderboard
    address[] public topReferrers;
    uint256 public constant LEADERBOARD_SIZE = 10;
    
    // ============ EVENTS ============
    
    event LPBonusClaimed(address indexed provider, uint256 amount);
    event AirdropClaimed(address indexed user, uint256 amount);
    event ReferralRecorded(address indexed user, address indexed referrer);
    event ReferralRewardPaid(address indexed referrer, uint256 amount);
    event LeaderboardUpdated(address indexed referrer, uint256 newCount);
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _pythToken) {
        owner = msg.sender;
        pythToken = _pythToken;
    }
    
    // ============ MODIFIERS ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    // ============ LP BONUS FUNCTIONS ============
    
    /**
     * @dev Claim LP bonus (first person to create liquidity pool)
     * @param poolAddress Address of the created liquidity pool
     */
    function claimLPBonus(address poolAddress) external {
        require(!lpBonusClaimed, "Bonus already claimed");
        require(poolAddress != address(0), "Invalid pool");
        
        // Verify pool exists (basic check)
        require(isContract(poolAddress), "Pool must be a contract");
        
        firstLPProvider = msg.sender;
        lpBonusClaimed = true;
        
        // Transfer bonus
        require(
            IERC20(pythToken).transfer(msg.sender, LP_BONUS),
            "Transfer failed"
        );
        
        emit LPBonusClaimed(msg.sender, LP_BONUS);
    }
    
    // ============ AIRDROP FUNCTIONS ============
    
    /**
     * @dev Claim airdrop (1000 PYTH per eligible user)
     * @param referrer Address of referrer (optional, use address(0) if none)
     */
    function claimAirdrop(address referrer) external {
        require(!hasClaimedAirdrop[msg.sender], "Already claimed");
        require(msg.sender != referrer, "Cannot refer yourself");
        
        hasClaimedAirdrop[msg.sender] = true;
        totalAirdropsClaimed++;
        
        // Record referral if provided
        if (referrer != address(0) && userReferrer[msg.sender] == address(0)) {
            userReferrer[msg.sender] = referrer;
            referralCount[referrer]++;
            
            emit ReferralRecorded(msg.sender, referrer);
            
            // Pay referral reward
            referralEarnings[referrer] += REFERRAL_REWARD;
            require(
                IERC20(pythToken).transfer(referrer, REFERRAL_REWARD),
                "Referral reward failed"
            );
            
            emit ReferralRewardPaid(referrer, REFERRAL_REWARD);
            
            // Update leaderboard
            updateLeaderboard(referrer);
        }
        
        // Transfer airdrop
        require(
            IERC20(pythToken).transfer(msg.sender, AIRDROP_AMOUNT),
            "Airdrop transfer failed"
        );
        
        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT);
    }
    
    // ============ REFERRAL FUNCTIONS ============
    
    /**
     * @dev Get referral stats for a user
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
        
        emit LeaderboardUpdated(referrer, referralCount[referrer]);
    }
    
    /**
     * @dev Get leaderboard
     */
    function getLeaderboard() external view returns (
        address[] memory referrerAddresses,
        uint256[] memory counts
    ) {
        referrerAddresses = new address[](topReferrers.length);
        counts = new uint256[](topReferrers.length);
        
        for (uint256 i = 0; i < topReferrers.length; i++) {
            referrerAddresses[i] = topReferrers[i];
            counts[i] = referralCount[topReferrers[i]];
        }
    }
    
    // ============ UTILITY FUNCTIONS ============
    
    /**
     * @dev Check if address is a contract
     */
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
    
    /**
     * @dev Emergency withdraw (owner only)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(
            IERC20(token).transfer(owner, amount),
            "Withdraw failed"
        );
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}

// ============ IERC20 INTERFACE ============

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
