---
sidebar_position: 2
title: Tokenomics
draft: true
---

# Tokenomics

Quantus has a fixed 21,000,000 QTC supply. **27% is minted at genesis** (the premine) and almost all of it is vested. The remaining **73% is emitted to miners** via proof of work. There is no dev tax and no treasury cut of block rewards — each block's reward and standard fees go 100% to the miner.

Source of truth: `runtime/src/genesis_config_presets/mainnet_vesting.rs`, `pallet_mining_rewards`, and `pallet_wormhole` volume-fee config.

## Supply

| Property | Value |
|----------|-------|
| Token | QTC |
| Decimals | 12 (`1 QTC = 10^12` planck) |
| Max supply | 21,000,000 |
| Genesis mint | 27% (5,670,000 QTC) |
| Mining emissions | 73% (15,330,000 QTC) |
| Emission model | Smooth exponential decay, no halvings |

The vesting pot also receives its existential deposit at genesis. That is the only issuance outside the 27%.

## Allocation

`GENESIS_ALLOCATION = 27% of MAX_SUPPLY`. Every coin of it is either a vesting row or a 3 QTC seed endowment. Compile-time assertion: `sum(VESTING) + 20 × SEED == GENESIS_ALLOCATION`.

| Bucket | Amount (QTC) | % of max supply | Unlock |
|--------|--------------|-----------------|--------|
| Spreadsheet grants | 4,957,502 | ~23.61% | 1-year lock from TGE, then linear over 3 years (`cliff == start`). One intents grant (42,000) vests from TGE over 365 days. |
| Treasury liquidity | 210,000 | 1% | Linear over 16 days from TGE, no lockup |
| Treasury remainder | 502,438 | ~2.39% | Same 1-year + 3-year grant clock |
| Governance seeds | 60 | ~0.0003% | 3 QTC liquid to each of 10 treasurers and 10 tech-collective members (fee/deposit seed) |
| **Miners** | **15,330,000** | **73%** | Earned via PoW; 100% of each block reward |

TGE is the first non-zero block timestamp, not the genesis block (`Now` at genesis is 0). Nothing in the vesting table unlocks as a lump.

The treasury is the 6-of-10 multisig of the treasurer set. It is not paid from mining.

## Emission

```
Block Reward = (MaxSupply - CurrentSupply) / EmissionDivisor
```

Mainnet `EmissionDivisor` is `50_000_000`. Rewards shrink as supply approaches the cap. There is no company/dev share of the block reward.

## Fees

| Transaction type | Fee model |
|------------------|-----------|
| Standard transfer | Weight + length fees, plus optional tip → miner |
| Wormhole exit | Volume fee (below) |
| High-security / reversible | 1% volume fee, burned (no miner split) |

### Wormhole volume fee

Charged on wormhole **exits** (`VolumeFeeRateBps = 4`, i.e. 0.04%). There is no separate on-chain minimum exit amount.

Settlement ceil-rounds once per accepted private segment, then sums those fees across a public batch. Small segments therefore pay at least one quantum (0.01 QTC); larger segments pay the headline rate.

The fee is split in whole quanta:

| Share | Rule |
|-------|------|
| Burn | `ceil(50% of fee)` — rounds against the miner; reduces `total_issuance` |
| Miner | Remainder after the burn |
| Aggregator (public batches only) | `floor(50% of the burn bucket)` redirected to the aggregator; leftover stays burned. The miner's share does not change. |

If the miner cannot be credited (no author, or mint fails), that miner share is burned instead of dropped. A failed aggregator rebate stays in the burn bucket and does not revert the exit.

## Funding History

| Round | Amount raised | Equity valuation | Token valuation | Lead |
|-------|---------------|------------------|-----------------|------|
| Private Round 1 | $1.65M | $20M | $40M | -- |
| Private Round 2 | $770K | $50M | $100M | Balaji Srinivasan |
| **Total raised** | **$2.42M** | | | |
