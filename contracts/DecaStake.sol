// SPDX-License-Identifier: No License

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICornToken {
    function mint(address, uint256) external;
}

contract DecaStake is Ownable {
    
    //Info of each user
    struct UserInfo {
        uint256 stakedAmount;           // User staked amount in the pool
        uint256 lastStakedTimestamp;    // User staked amount in the pool
        uint256 lastUnstakedTimestamp;  // User staking timestamp
        uint256 lastHarvestTimestamp;   // User last harvest timestamp 
    }
    
    // Info of each pool.
    struct PoolInfo {
        uint256 rate;           // Fixed rewards rate
        uint256 stakeLimit;     // Fixed staking amount 
        uint256 totalStaked;    // Total staked tokens in the pool
        bool paused;            // Pause or unpause the pool, failover plan
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    IERC20 public decaToken;
    ICornToken public cornToken;

    address public feeReceiver;
    uint256 public unstakeFee = 10;
    uint256 public rewardPeriod = 86400;    //daily 86400 seconds

    event Staked(address indexed account, uint256 pid, uint256 startTime, uint256 amount);
    event Harvested(address indexed account, uint256 pid, uint256 value);
    event Unstaked(address indexed account, uint256 pid, uint256 amount);
    event RegisterPool(uint256 rate, uint256 stakeLimit);
    event UpdatePool(uint256 rate, uint256 stakeLimit, bool paused);

    event SetRewardPeriod(uint256 rewardPeriod);
    event SetUnstakeFee(uint256 unstakeFee);
    event ClearStuckBalance(address to, uint256 balance);

    constructor(address _decaToken, address _cornToken, address _feeReceiver) {
        require(_feeReceiver != address(0), "Address Zero");

        decaToken = IERC20(_decaToken);
        cornToken = ICornToken(_cornToken); 
        feeReceiver = _feeReceiver;
    }

    // register a pool. Can only be called by the owner.
    function registerPool(uint256 _rate, uint256 _stakeLimit) public onlyOwner {

        poolInfo.push(PoolInfo({
            rate : _rate,
            stakeLimit : _stakeLimit,
            totalStaked : 0,
            paused: false
        }));
        
        emit RegisterPool(_rate, _stakeLimit);
    }

    // Update the pool detail, given pid of the pool. Can only be called by the owner.
    function updatePool(uint256 _pid, uint256 _rate, uint256 _stakeLimit, bool _paused) public onlyOwner {
        
        PoolInfo storage _poolInfo = poolInfo[_pid];
        _poolInfo.rate = _rate;
        _poolInfo.stakeLimit = _stakeLimit;
        _poolInfo.paused = _paused;

        emit UpdatePool(_rate, _stakeLimit, _paused);
    }

    function stake(uint256 _pid, uint256 _amount) external returns (uint256) {  

        PoolInfo storage _poolInfo = poolInfo[_pid];
        UserInfo storage _userInfo = userInfo[_pid][msg.sender];

        require(!_poolInfo.paused, "stake : Contract paused, please try again later");
        require(_poolInfo.stakeLimit == _amount, "stake : Incorrect staking amount");
        require(_userInfo.stakedAmount == 0, "stake : Already staking in this pool");
        require(decaToken.balanceOf(msg.sender) >= _amount, "stake : Insufficient DECA token");
        
        // Update user staking info
        _userInfo.stakedAmount = _amount;
        _userInfo.lastStakedTimestamp = block.timestamp;
        _userInfo.lastHarvestTimestamp = block.timestamp; //must set lastHarvestTimestamp, used for rewards calculation
        
        // Update pool info
        _poolInfo.totalStaked += _amount;

        decaToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _pid, block.timestamp, _amount);
        return _amount;
    }

    function unstake(uint256 _pid) external returns (uint256) {
        PoolInfo storage _poolInfo = poolInfo[_pid];
        UserInfo storage _userInfo = userInfo[_pid][msg.sender];

        require(!_poolInfo.paused, "unstake : Contract paused, please try again later");
        require(_userInfo.stakedAmount > 0, "unstake : You dont have stake");
        require(decaToken.balanceOf(address(this)) >= _userInfo.stakedAmount, "unstake : Contract doesnt have enough DECA, please contact admin");

        uint256 _stakedAmount = _userInfo.stakedAmount;
        uint256 _fee = _userInfo.stakedAmount * unstakeFee / 100;
        uint256 _unstakeAmount = _stakedAmount - _fee;

        // Harvest before unstake
        harvest(_pid);  

        // Update userinfo
        _userInfo.stakedAmount = 0;
        _userInfo.lastUnstakedTimestamp = block.timestamp;

        _poolInfo.totalStaked -= _stakedAmount;    // Update pool total stake token

        decaToken.transfer(feeReceiver, _fee);   // Transfer unstake fee to fee receiver
        decaToken.transfer(msg.sender, _unstakeAmount); // Transfer DECA token back to the owner

        emit Unstaked(msg.sender, _pid, _unstakeAmount);
        return _unstakeAmount;
    }

    function harvest(uint256 _pid) public returns (uint256){

        PoolInfo storage _poolInfo = poolInfo[_pid];
        UserInfo storage _userInfo = userInfo[_pid][msg.sender];

        require(!_poolInfo.paused, "harvest : Contract paused, please try again later");
        require(_userInfo.stakedAmount > 0, "harvest : You dont have stake");

        uint256 _value = getStakeRewards(_pid, msg.sender);
        require(_value > 0, "harvest : You do not have any pending rewards");

        _userInfo.lastHarvestTimestamp = block.timestamp;   // Update user last harvest timestamp
        mintCorn(msg.sender, _value);   // Mint CORN rewards to user

        emit Harvested(msg.sender, _pid, _value);
        return _value;
    }

    function getStakeRewards(uint256 _pid, address _address) public view returns (uint256) {
       
        PoolInfo storage _poolInfo = poolInfo[_pid];
        UserInfo storage _userInfo = userInfo[_pid][_address];

        if (_userInfo.stakedAmount == 0) return (0);

        uint256 _timePassed = block.timestamp - _userInfo.lastHarvestTimestamp;
        uint256 _reward = _timePassed * _poolInfo.rate / rewardPeriod;    //Rewards divided by 1 day, 86400 seconds

        return _reward;
    }

    function mintCorn(address _to, uint256 _amount) internal {
        cornToken.mint(_to, _amount);
    }

    function setRewardPeriod(uint256 _rewardPeriod) external onlyOwner {
        rewardPeriod = _rewardPeriod;

        emit SetRewardPeriod(_rewardPeriod);
    }

    function setUnstakeFee(uint256 _unstakeFee) external onlyOwner {
        require(_unstakeFee <= 20, "Only allow up to 20% unstake fee");
        unstakeFee = _unstakeFee;

        emit SetUnstakeFee(_unstakeFee);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

	function clearStuckBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);

        emit ClearStuckBalance(owner(), balance);
    }
}