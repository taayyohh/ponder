// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IPonderMasterChef.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderPair.sol";
import "../interfaces/IERC20.sol";
import "./PonderToken.sol";

contract PonderMasterChef is IPonderMasterChef {
    /// @notice The PONDER token
    PonderToken public immutable ponder;

    /// @notice DEX factory for validating LP tokens
    IPonderFactory public immutable factory;

    /// @notice PONDER tokens created per second
    uint256 public ponderPerSecond;

    /// @notice Info of each pool
    PoolInfo[] public poolInfo;

    /// @notice Info of each user that stakes LP tokens
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /// @notice Total allocation points across all pools
    uint256 public totalAllocPoint;

    /// @notice Start time of rewards
    uint256 public immutable startTime;

    /// @notice Treasury address for deposit fees
    address public treasury;

    /// @notice Address with admin privileges
    address public owner;

    /// @notice Future owner in 2-step transfer
    address public pendingOwner;

    error Forbidden();
    error InvalidPool();
    error InvalidPair();
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientAmount();

    modifier onlyOwner {
        if (msg.sender != owner) revert Forbidden();
        _;
    }

    constructor(
        PonderToken _ponder,
        IPonderFactory _factory,
        address _treasury,
        uint256 _ponderPerSecond,
        uint256 _startTime
    ) {
        if (_treasury == address(0)) revert ZeroAddress();
        ponder = _ponder;
        factory = _factory;
        treasury = _treasury;
        ponderPerSecond = _ponderPerSecond;
        startTime = _startTime;
        owner = msg.sender;
    }

    /// @notice Returns the number of pools
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @notice View function to see pending PONDER rewards
    function pendingPonder(uint256 _pid, address _user)
    external
    view
    returns (uint256 pending)
    {
        if (_pid >= poolInfo.length) revert InvalidPool();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accPonderPerShare = pool.accPonderPerShare;
        if (block.timestamp > pool.lastRewardTime && pool.totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
            uint256 ponderReward = (timeElapsed * ponderPerSecond * pool.allocPoint) / totalAllocPoint;
            accPonderPerShare += (ponderReward * 1e12) / pool.totalStaked;
        }

        pending = (user.amount * accPonderPerShare) / 1e12 - user.rewardDebt;

        // Apply boost if user has staked PONDER
        if (user.ponderStaked > 0 && pool.boostMultiplier > 10000) {
            uint256 boost = (pending * (pool.boostMultiplier - 10000)) / 10000;
            pending += boost;
        }
    }

    /// @notice Add a new LP pool
    function add(
        uint256 _allocPoint,
        address _lpToken,
        uint16 _depositFeeBP,
        uint16 _boostMultiplier,
        bool _withUpdate
    ) external onlyOwner {
        if (_depositFeeBP > 1000) revert InvalidPool(); // max 10% fee
        if (_boostMultiplier < 10000) revert InvalidPool(); // min 1x boost
        if (_boostMultiplier > 30000) revert InvalidPool(); // max 3x boost

        if (_withUpdate) {
            massUpdatePools();
        }

        // Validate LP token is from our factory
        address token0 = IPonderPair(_lpToken).token0();
        address token1 = IPonderPair(_lpToken).token1();
        if (factory.getPair(token0, token1) != _lpToken) revert InvalidPair();

        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint += _allocPoint;

        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardTime: lastRewardTime,
            accPonderPerShare: 0,
            totalStaked: 0,
            depositFeeBP: _depositFeeBP,
            boostMultiplier: _boostMultiplier
        }));

        emit PoolAdded(poolInfo.length - 1, _lpToken, _allocPoint);
    }

    /// @notice Update reward variables for all pools
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /// @notice Update reward variables of the given pool
    function updatePool(uint256 _pid) public {
        if (_pid >= poolInfo.length) revert InvalidPool();
        PoolInfo storage pool = poolInfo[_pid];

        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        if (pool.totalStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
        uint256 ponderReward = (timeElapsed * ponderPerSecond * pool.allocPoint) / totalAllocPoint;

        // Mint rewards
        ponder.mint(address(this), ponderReward);
        pool.accPonderPerShare += (ponderReward * 1e12) / pool.totalStaked;
        pool.lastRewardTime = block.timestamp;
    }

    /// @notice Update allocation points of a pool
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        if (_pid >= poolInfo.length) revert InvalidPool();

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        emit PoolUpdated(_pid, _allocPoint);
    }

    /// @notice Deposit LP tokens to earn PONDER rewards
    function deposit(uint256 _pid, uint256 _amount) external {
        if (_pid >= poolInfo.length) revert InvalidPool();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        // Harvest existing rewards
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accPonderPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                safePonderTransfer(msg.sender, pending);
            }
        }

        if (_amount > 0) {
            uint256 beforeBalance = IERC20(pool.lpToken).balanceOf(address(this));
            IERC20(pool.lpToken).transferFrom(msg.sender, address(this), _amount);
            uint256 afterBalance = IERC20(pool.lpToken).balanceOf(address(this));
            _amount = afterBalance - beforeBalance; // Handle tokens with transfer tax

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = (_amount * pool.depositFeeBP) / 10000;
                IERC20(pool.lpToken).transfer(treasury, depositFee);
                _amount = _amount - depositFee;
            }

            user.amount += _amount;
            pool.totalStaked += _amount;
        }

        user.rewardDebt = (user.amount * pool.accPonderPerShare) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraw LP tokens
    function withdraw(uint256 _pid, uint256 _amount) external {
        if (_pid >= poolInfo.length) revert InvalidPool();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.amount < _amount) revert InsufficientAmount();

        updatePool(_pid);

        // Harvest rewards
        uint256 pending = (user.amount * pool.accPonderPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safePonderTransfer(msg.sender, pending);
        }

        if (_amount > 0) {
            user.amount -= _amount;
            pool.totalStaked -= _amount;
            IERC20(pool.lpToken).transfer(msg.sender, _amount);
        }

        user.rewardDebt = (user.amount * pool.accPonderPerShare) / 1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Emergency withdraw LP tokens without caring about rewards
    function emergencyWithdraw(uint256 _pid) external {
        if (_pid >= poolInfo.length) revert InvalidPool();
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        pool.totalStaked -= amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.ponderStaked = 0;

        IERC20(pool.lpToken).transfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    /// @notice Stake PONDER tokens to boost rewards
    function boostStake(uint256 _pid, uint256 _amount) external {
        if (_pid >= poolInfo.length) revert InvalidPool();
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        // Harvest existing rewards
        uint256 pending = (user.amount * poolInfo[_pid].accPonderPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safePonderTransfer(msg.sender, pending);
        }

        if (_amount > 0) {
            ponder.transferFrom(msg.sender, address(this), _amount);
            user.ponderStaked += _amount;
        }

        user.rewardDebt = (user.amount * poolInfo[_pid].accPonderPerShare) / 1e12;
        emit BoostStake(msg.sender, _pid, _amount);
    }

    /// @notice Unstake PONDER tokens used for boost
    function boostUnstake(uint256 _pid, uint256 _amount) external {
        if (_pid >= poolInfo.length) revert InvalidPool();
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.ponderStaked < _amount) revert InsufficientAmount();

        updatePool(_pid);

        // Harvest existing rewards
        uint256 pending = (user.amount * poolInfo[_pid].accPonderPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safePonderTransfer(msg.sender, pending);
        }

        user.ponderStaked -= _amount;
        ponder.transfer(msg.sender, _amount);

        user.rewardDebt = (user.amount * poolInfo[_pid].accPonderPerShare) / 1e12;
        emit BoostUnstake(msg.sender, _pid, _amount);
    }

    /// @notice Safe PONDER transfer function, just in case if rounding error causes pool to not have enough PONDER
    function safePonderTransfer(address _to, uint256 _amount) internal {
        uint256 ponderBalance = ponder.balanceOf(address(this));
        if (_amount > ponderBalance) {
            ponder.transfer(_to, ponderBalance);
        } else {
            ponder.transfer(_to, _amount);
        }
    }

    // Add new function
    /// @notice Update treasury address
    /// @param _treasury New treasury address
    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(oldTreasury, _treasury);
    }
}
