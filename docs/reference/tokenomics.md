---
sidebar_position: 2
title: Tokenomics
draft: true
---

# Tokenomics

Quantus follows Bitcoin's monetary model: fixed supply, proof-of-work distribution, no pre-mine. Key improvements include smooth emission curves (no halving cliffs) and a dev tax that avoids Bitcoin's early-miner concentration problem.

## Supply

**Maximum Supply: 21,000,000 QU**

| Property | Value |
|----------|-------|
| Token | QU |
| Decimals | 12 |
| Max Supply | 21,000,000 |
| Emission Model | Smooth exponential decay |
| ~99% Emitted | Within ~40 years |

## Emission Schedule

```
Block Reward = (MaxSupply - CurrentSupply) / EmissionDivisor
```

Unlike Bitcoin's abrupt halvings every 4 years, Quantus uses continuous exponential decay. This:
- Avoids mining incentive cliffs that disrupt economics at halving boundaries
- Creates predictable, gradually decreasing rewards
- Ensures miners always have meaningful block rewards

## Token Allocation

Assuming public sale hard cap fills:

| Bucket | % of Supply | Mechanism | Lockup |
|--------|-------------|-----------|--------|
| **Miners** | 50% | Earned via PoW over ~40 years | N/A (earned) |
| **Private Investors** | 15% | Sold in private rounds | **100% liquid day 1** |
| **Public Sale** | 10% | Public sale (hard cap, variable fill) | **100% liquid day 1** |
| **DEX Liquidity** | 10% | Paired with USDC from public sale | Locked in LP |
| **Company** | 15% | Dev tax on block rewards (~5 years to fully vest) | Earned gradually |

### TGE vs Mining

- **TGE Minted:** 35% (7,350,000 QU) -- Private sale + Public sale + DEX Liquidity
- **Mining Emissions:** 65% (13,650,000 QU) -- Miners + Company dev tax, over ~40 years

### No Pre-Mine

There is no pre-mine. Investor tokens (private + public) are minted at TGE. Company tokens are earned gradually via the dev tax on block rewards, not minted upfront. This avoids Bitcoin's early supply curve problem where early miners (e.g., Satoshi) accumulated massive holdings.

## Lockup Schedule

| Group | Schedule |
|-------|----------|
| Team and Founders | 1-year cliff, then linear monthly over 3 years |
| Advisors | 1-year cliff, then linear monthly over 3 years |
| Private Investors | **100% liquid day 1** |
| Public Sale | **100% liquid day 1** |
| Company (dev tax) | Earned via block rewards (~5 years) |
| Liquidity | Paired in LP |

## Fee Structure

| Transaction Type | Fee Model |
|-----------------|-----------|
| Standard transfer | Miner tip (priority fee) |
| Wormhole transaction | Volume fee split: miner + **burn** |
| High-security transaction | Volume fee split: miner + **burn** |

The burn component on wormhole and high-security transactions creates deflationary pressure, partially offsetting emission over time.

## Funding History

| Round | Amount Raised | Equity Valuation | Token Valuation | Lead |
|-------|--------------|-----------------|-----------------|------|
| Private Round 1 | $1.65M | $20M | $40M | -- |
| Private Round 2 | $770K | $50M | $100M | Balaji Srinivasan |
| **Total Raised** | **$2.42M** | | | |

**Supply sold:** 7% (private rounds)

Industry standard: token valuation = 2x equity valuation. All contracts reflect this.

## Current / Planned Raise

| Round | Format | Supply | Valuation |
|-------|--------|--------|-----------|
| Private Round 3 | Token sale (seeking anchor investor) | 8% | $100M token |
| Public Sale | NEAR launchpad + CoinList/Echo | Up to 10% (hard cap) | $100M token |

- Token sales only going forward (no more equity rounds)
- Public sale proceeds are paired with equal QU into DEX liquidity
- Target: Public sale May 2026, TGE June 2026
