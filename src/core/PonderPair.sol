// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ILaunchToken.sol";
import "../interfaces/IPonderCallee.sol";
import "../interfaces/IPonderFactory.sol";
import "../interfaces/IPonderPair.sol";
import "../interfaces/IPonderRouter.sol";

import "../libraries/Math.sol";
import "../libraries/UQ112x112.sol";
import "./PonderERC20.sol";

contract PonderPair is PonderERC20("Ponder LP", "PONDER-LP"), IPonderPair {
    using UQ112x112 for uint224;

    // Fee split configuration
    uint256 private constant STAKING_FEE_SPLIT = 5000; // 50% in basis points
    uint256 private constant BASIS_POINTS = 10000;
    uint256 public constant override MINIMUM_LIQUIDITY = 1000;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public override factory;
    address public override token0;
    address public override token1;
    address public immutable stablecoin;
    IPonderRouter public immutable router;

    // Reserve tracking
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    // Price tracking for oracles
    uint256 public override price0CumulativeLast;
    uint256 public override price1CumulativeLast;
    uint256 public override kLast;

    // Lock for single-transaction reentrancy guard
    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _stablecoin, address _router) {
        factory = msg.sender;
        stablecoin = _stablecoin;
        router = IPonderRouter(_router);
    }

    function launcher() public view returns (address) {
        return IPonderFactory(factory).launcher();
    }

    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, "FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view override returns (
        uint112 _reserve0,
        uint112 _reserve1,
        uint32 _blockTimestampLast
    ) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function _update(
        uint256 balance0,
        uint256 balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);  // Collect fees first
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                amount0 * _totalSupply / _reserve0,
                amount1 * _totalSupply / _reserve1
            );
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);

        // Update kLast after everything else
        if (feeOn) kLast = uint256(reserve0) * reserve1;

        emit Mint(msg.sender, amount0, amount1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IPonderFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                uint256 currentK = uint256(_reserve0) * uint256(_reserve1);
                uint256 rootK = Math.sqrt(currentK);
                uint256 rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 totalFees = numerator / denominator;

                    // Split fees between LP and staking
                    uint256 lpFees = (totalFees * (BASIS_POINTS - STAKING_FEE_SPLIT)) / BASIS_POINTS;
                    uint256 stakingFees = (totalFees * STAKING_FEE_SPLIT) / BASIS_POINTS;

                    if (stakingFees > 0) {
                        _handleStakingFees(stakingFees, _reserve0, _reserve1);
                    }

                    if (lpFees > 0) {
                        // Handle LaunchToken fees as before
                        try ILaunchToken(token0).launcher() returns (address launchToken0Launcher) {
                            if (launchToken0Launcher == launcher()) {
                                address tokenCreator = ILaunchToken(token0).creator();
                                uint256 creatorShare = lpFees / 3;
                                _mint(tokenCreator, creatorShare);
                                _mint(feeTo, lpFees - creatorShare);
                                return true;
                            }
                        } catch {}

                        try ILaunchToken(token1).launcher() returns (address launchToken1Launcher) {
                            if (launchToken1Launcher == launcher()) {
                                address tokenCreator = ILaunchToken(token1).creator();
                                uint256 creatorShare = lpFees / 3;
                                _mint(tokenCreator, creatorShare);
                                _mint(feeTo, lpFees - creatorShare);
                                return true;
                            }
                        } catch {}

                        _mint(feeTo, lpFees);
                    }
                }
            }
            kLast = uint256(_reserve0) * uint256(_reserve1);
        } else if (_kLast != 0) {
            kLast = 0;
        }
        return feeOn;
    }
    function _handleStakingFees(uint256 stakingFees, uint112 _reserve0, uint112 _reserve1) private {
        // Mint LP tokens to this contract
        _mint(address(this), stakingFees);

        // Calculate token amounts based on reserves
        uint256 amount0 = (stakingFees * uint256(_reserve0)) / totalSupply();
        uint256 amount1 = (stakingFees * uint256(_reserve1)) / totalSupply();

        // Approve router to spend our tokens
        IERC20(token0).approve(address(router), amount0);
        IERC20(token1).approve(address(router), amount1);

        // Convert to stablecoin using optimal path
        address[] memory path0 = new address[](2);
        path0[0] = token0;
        path0[1] = stablecoin;

        address[] memory path1 = new address[](2);
        path1[0] = token1;
        path1[1] = stablecoin;

        // Swap both tokens to stablecoin
        if (amount0 > 0) {
            router.swapExactTokensForTokens(
                amount0,
                0, // Accept any amount of stablecoin
                path0,
                IPonderFactory(factory).stakingContract(),
                block.timestamp
            );
        }

        if (amount1 > 0) {
            router.swapExactTokensForTokens(
                amount1,
                0, // Accept any amount of stablecoin
                path1,
                IPonderFactory(factory).stakingContract(),
                block.timestamp
            );
        }

        // Burn the LP tokens after conversion
        _burn(address(this), stakingFees);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputAmount();

        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        if (amount0Out > _reserve0 || amount1Out > _reserve1) revert InsufficientLiquidity();

        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;

            if (to == _token0 || to == _token1) revert InvalidTo();
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) IPonderCallee(to).ponderCall(msg.sender, amount0Out, amount1Out, data);

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // Calculate amounts in based on balances
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        if (amount0In == 0 && amount1In == 0) revert InsufficientInputAmount();

        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted;
            uint256 balance1Adjusted;
            bool isLaunchToken0;
            bool isLaunchToken1;

            // Check if either token is a LaunchToken from our launcher
            try ILaunchToken(token0).launcher() returns (address launchLauncher0) {
                isLaunchToken0 = (launchLauncher0 == launcher());
            } catch {}
            try ILaunchToken(token1).launcher() returns (address launchLauncher1) {
                isLaunchToken1 = (launchLauncher1 == launcher());
            } catch {}

            // If token being sold is a LaunchToken, split fee between LP (0.2%) and creator (0.1%)
            if ((amount0In > 0 && isLaunchToken0) || (amount1In > 0 && isLaunchToken1)) {
                if (amount0In > 0) {
                    address tokenCreator = ILaunchToken(token0).creator();
                    balance0Adjusted = (balance0 * 1000) - (amount0In * 2); // 0.2% LP fee
                    _safeTransfer(token0, tokenCreator, (amount0In * 1) / 1000); // 0.1% creator fee
                    balance1Adjusted = (balance1 * 1000); // No fee on output token
                } else {
                    address tokenCreator = ILaunchToken(token1).creator();
                    balance1Adjusted = (balance1 * 1000) - (amount1In * 2); // 0.2% LP fee
                    _safeTransfer(token1, tokenCreator, (amount1In * 1) / 1000); // 0.1% creator fee
                    balance0Adjusted = (balance0 * 1000); // No fee on output token
                }
            } else {
                // Regular 0.3% LP fee for non-LaunchTokens
                balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
                balance1Adjusted = (balance1 * 1000) - (amount1In * 3);
            }

            if (balance0Adjusted * balance1Adjusted < uint256(_reserve0) * uint256(_reserve1) * 1000000) {
                revert InsufficientInputAmount();
            }
        }

        _update(balance0, balance1, _reserve0, _reserve1);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getKLast() external view returns (uint256) {
        return kLast;
    }

    function burn(address to) external override lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = this.balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);  // Collect fees first
        uint256 _totalSupply = totalSupply();

        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);

        // Update kLast if fees are enabled
        if (feeOn) {
            kLast = uint256(reserve0) * reserve1;
        }

        emit Burn(msg.sender, amount0, amount1, to);
    }

    // Add these error definitions if not already present
    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error InvalidTo();
    error InsufficientInputAmount();

    function skim(address to) external override lock {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(
            _token0,
            to,
            IERC20(_token0).balanceOf(address(this)) - reserve0
        );
        _safeTransfer(
            _token1,
            to,
            IERC20(_token1).balanceOf(address(this)) - reserve1
        );
    }

    function sync() external override lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
}
