# Ponder Protocol

Ponder is a decentralized exchange protocol built specifically for Bitkub Chain. Building on Uniswap V2's proven foundation, Ponder introduces yield farming through the PONDER token while maintaining the core AMM functionality that powers decentralized trading.

The protocol uses automated market making (AMM) to enable permissionless trading. Liquidity providers deposit pairs of tokens into pools to create trading markets. Every pool employs the constant product formula (x * y = k) to determine exchange rates, with a 0.3% fee on trades that rewards liquidity providers. The protocol's price oracle system accumulates time-weighted prices, providing TWAP (Time-Weighted Average Price) data feeds that other protocols can reliably use.

## PONDER Token

The PONDER token ($PONDER) drives the protocol's economic incentives with the following specifications:

* Maximum supply cap: 1,000,000,000 (1 billion) tokens
* Distribution timeline: 4 years for farming allocation, after which minting is permanently disabled
* Initial Distribution:
    - Treasury/DAO: 25% (250M)
    - Team/Reserve: 15% (150M, vested over 1 year)
    - Initial Liquidity: 10% (100M)
    - Marketing: 10% (100M)
    - Farming allocation: 40% (400M, distributed over 4 years)
* Vesting:
    - Team allocation vests linearly over 365 days
    - Farm rewards are distributed per second over 4 years
* Minting control: Restricted to MasterChef contract for farming portion only
* Ownership model: Two-step ownership transfer with pending owner mechanism
* Future utility: Protocol governance (planned)


## Yield Farming System

The farming system, powered by MasterChef, introduces several sophisticated mechanics:

Base Farming:
  
LP token staking earns PONDER rewards
Rewards calculated per second based on pool allocations
Multiple pools with customizable reward weights

Reward Boosting:
  
Users can stake PONDER to enhance farming yields
Boost multipliers scale up to 3x base rate
Boost calculation based on PONDER stake amount
Independent boosts per pool

Pool Management:
  
Configurable allocation points per pool
Deposit fees (up to 10%) support protocol treasury
Real-time reward rate adjustments
Emergency withdrawal functionality

Reward Distribution:
  
Automatic reward compounding
Safe reward transfer handling
Mass pool updates for efficiency

## Getting Started


Copy
# Install
git clone https://github.com/yourusername/ponder-protocol.git
cd ponder-protocol
forge install

# Build
forge build

# Test
forge test
## Contract Interactions

For users looking to interact with the protocol:

Providing Liquidity:
 
Approve tokens to Router contract
Call addLiquidity() with desired amounts
Receive LP tokens representing pool share

Trading:
 
Approve tokens to Router contract
Use swap functions with specified paths
Set reasonable slippage tolerance

Farming:
 
Stake LP tokens in MasterChef
Optionally stake PONDER for boosted rewards
Harvest rewards anytime
Compound or withdraw as needed

Using Price Feed:
 
Query pairs for current reserves
Access TWAP data through oracle views
Customize time windows for price accuracy

## License

MIT License - see [LICENSE](LICENSE)

While the protocol builds on proven mechanics, users should conduct their own review before participation.
