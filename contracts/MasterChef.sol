//SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICornToken {
    function mint(address, uint256) external;
}

contract MasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardBlock; // Last block number that CORNs distribution occurs.
        uint256 accCornPerShare; // Accumulated CORNs per share, times 1e12. See below.
    }

    ICornToken public corn;
    uint256 public cornPerBlock;
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) public registeredTokens;

    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    bool public migrated = false;

    // Fee
    uint256 public fee = 10;
    address public feeRecipient;

    constructor(
        address _corn,
        uint256 _cornPerBlock,
        uint256 _startBlock,
        address _feeRecipient
    ) {
        corn = ICornToken(_corn); 
        cornPerBlock = _cornPerBlock;
        startBlock = _startBlock;
        feeRecipient = _feeRecipient;
    }

    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid != 0, "Deposit DECA by staking");
        require(_pid < poolInfo.length, "Invalid PID");
        require(migrated, "Can only stake after migration");

        stake(_pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid != 0, "withdraw DECA by unstaking");
        require(_pid < poolInfo.length, "Invalid PID");

        unstake(_pid, _amount);
    }

    function enterStaking(uint256 _amount) external nonReentrant {
        require(migrated, "Can only stake after migration");
        
        stake(0, _amount);
    }

    function leaveStaking(uint256 _amount) external nonReentrant {
        unstake(0, _amount);
    }

    function stake(uint256 _pid, uint256 _amount) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accCornPerShare / 1e12) - user.rewardDebt;
            if (pending > 0) {
                mintCornRewards(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount + _amount;
        }
        user.rewardDebt = user.amount * pool.accCornPerShare / 1e12;

        emit Stake(msg.sender, _pid, _amount);
    }

    function unstake(uint256 _pid, uint256 _amount) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = (user.amount * pool.accCornPerShare / 1e12) - user.rewardDebt;
        if (pending > 0) {
            mintCornRewards(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;

            // Transfer fee to feeRecipient
            uint256 _fee = _amount * fee / 100;
            pool.lpToken.safeTransfer(feeRecipient, _fee);
        
            // Transfer token to user
            pool.lpToken.safeTransfer(address(msg.sender), _amount - _fee);
        }
        user.rewardDebt = user.amount * pool.accCornPerShare / 1e12;

        emit Unstake(msg.sender, _pid, _amount);
    }

    function add(uint256 _allocPoint, address _lpToken, bool _withUpdate) external onlyOwner {
        require(_lpToken != address(0), "Address zero");
        require(!registeredTokens[_lpToken], "LP already registered");

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo(
                {
                    lpToken: IERC20(_lpToken), 
                    allocPoint: _allocPoint, 
                    lastRewardBlock: lastRewardBlock, 
                    accCornPerShare: 0
                }
            )
        );

        // Register the pool
        registeredTokens[_lpToken] = true;

        emit Add(_allocPoint, _lpToken, _withUpdate);
    }

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if(_pid > 0)
            require(_pid < poolInfo.length, "Invalid PID");

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint - prevAllocPoint + _allocPoint;
        }

        emit Set(_pid, _allocPoint, _withUpdate);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        require(_pid < poolInfo.length, "Invalid PID");

        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 cornReward = multiplier * cornPerBlock * pool.allocPoint / totalAllocPoint;

        pool.accCornPerShare = pool.accCornPerShare + (cornReward * 1e12 / lpSupply);
        pool.lastRewardBlock = block.number;
    }

    function migrate(
        uint256 _pid, 
        address[] memory _userAddressList, 
        uint256[] memory _amountList, 
        uint256[] memory _rewardDebt,
        uint256 _lastRewardBlock,
        uint256 _accCornPerShare) external onlyOwner 
    {
        require(!migrated, "Only can call once");
        require(_userAddressList.length == _amountList.length, "Length mismatch");
        require(_userAddressList.length == _rewardDebt.length, "Length mismatch");
        require(_pid < poolInfo.length, "Invalid PID");

        for (uint256 i = 0; i < _userAddressList.length; i++) {
            UserInfo storage user = userInfo[_pid][_userAddressList[i]];
            user.amount = user.amount + _amountList[i];
            user.rewardDebt = user.rewardDebt + _rewardDebt[i];
        }

        // Set pool details
        poolInfo[_pid].lastRewardBlock = _lastRewardBlock;
        poolInfo[_pid].accCornPerShare = _accCornPerShare;

        migrated = true;

        // Update pool 
        updatePool(_pid);

        emit Migrate(_pid, _userAddressList, _amountList, _rewardDebt, _lastRewardBlock, _accCornPerShare);
    }

    function updateMultiplier(uint256 _multiplier) external onlyOwner {
        require(_multiplier > 0, "Value zero");
        
        massUpdatePools();
        BONUS_MULTIPLIER = _multiplier;
        emit UpdateMultiplier(_multiplier);
    }

    function setCornPerBlock(uint256 _cornPerBlock) external onlyOwner {
        require(_cornPerBlock > 0, "Value zero");

        massUpdatePools();
        cornPerBlock = _cornPerBlock;
        
        emit SetCornPerBlock(_cornPerBlock);
    }

    function pendingCorn(uint256 _pid, address _user) external view returns (uint256) {
        require(_pid < poolInfo.length, "Invalid PID");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCornPerShare = pool.accCornPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 cornReward = multiplier * cornPerBlock * pool.allocPoint / totalAllocPoint;
            accCornPerShare = accCornPerShare + (cornReward * 1e12 / lpSupply);
        }
        return (user.amount * accCornPerShare / 1e12) - user.rewardDebt;
    }

    function rescueToken(address _token, address _to, uint256 _amount) external onlyOwner {
        require(!registeredTokens[_token], "Cannot rescue registered tokens");
        require(_to != address(0), "Address zero");
        require(_amount > 0, "Amount zero");

        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        require(_amount <= _contractBalance, "Insufficient token");

        IERC20(_token).safeTransfer(_to, _amount);

        emit RescueToken(_token, _to, _amount);
    }

    function mintCornRewards(address _to, uint256 _amount) internal {
        corn.mint(_to, _amount);

        emit MintCornRewards(_to, _amount);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 10, "Exceeded max threshold");
        fee = _fee;

        emit SetFee(_fee);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Address zero");
        feeRecipient = _feeRecipient;

        emit SetFeeRecipient(_feeRecipient);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return (_to - _from) * BONUS_MULTIPLIER;
    }

    event Stake(address indexed user, uint256 indexed pid, uint256 amount);
    event Unstake(address indexed user, uint256 indexed pid, uint256 amount);
    event Add(uint256 allocPoint, address lpToken, bool withUpdate);
    event Set(uint256 pid, uint256 allocPoint, bool withUpdate);
    event Migrate(
        uint256 pid, 
        address[] userAddressList, 
        uint256[] amountList, 
        uint256[] _rewardDebt, 
        uint256 _lastRewardBlock,
        uint256 _accCornPerShare
    );
    event UpdateMultiplier(uint256 multiplier);
    event SetCornPerBlock(uint256 cornPerBlock);
    event RescueToken(address token, address to, uint256 amount);
    event MintCornRewards(address to, uint256 amount);
    event SetFee(uint256 fee);
    event SetFeeRecipient(address feeRecipient);
}
