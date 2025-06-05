# Vesting Scenarios in Quantus Governance

<div class="bs-callout bs-callout-warning">
  <h4><i class="fas fa-exclamation-triangle"></i>Implementation Examples</h4>

    The scenarios described below are examples of possibilities provided by the pallets used in the system with their current configuration. These examples demonstrate the capabilities of the underlying pallets but may not reflect the exact implementation in production.

</div>

## Basic Grant Application with Vesting

The basic grant application process demonstrates a two-stage governance pattern:

1. **Initial Approval**: Community referendum approves the principle of the grant
2. **Implementation**: Treasury council implements the approved grant with appropriate vesting schedule

### Key Components:
- Treasury track for initial approval
- Vesting schedule implementation after approval
- Conviction voting for community participation
- Configurable vesting periods based on grant type

## Multi-Milestone Grant Process

This scenario implements a progressive funding approach with multiple milestones:

1. **Initial Plan Approval**: Single referendum approves the entire grant plan
2. **Milestone-Based Releases**: Each milestone is evaluated by the Technical Collective
3. **Dynamic Vesting**: Vesting schedules are adjusted based on milestone quality

### Features:
- Atomic milestone funding
- Multiple vesting schedules
- Technical Collective oversight
- Quality-based vesting adjustments

## Technical Collective Milestone Evaluation

The Technical Collective plays a crucial role in milestone evaluation:

1. **Initial Approval**: Community referendum approves overall grant plan
2. **Milestone Evaluation**: Technical Collective evaluates each milestone
3. **Vesting Determination**: Technical Collective sets vesting schedules based on quality

### Process Flow:
1. Grantee delivers milestone proof
2. Technical Collective evaluates the work
3. Payment is released with appropriate vesting schedule
4. Vesting period is determined by quality assessment

## Emergency Vesting Operations

The system includes mechanisms for emergency intervention:

1. **Schedule Management**: Ability to modify or merge vesting schedules
2. **Atomic Operations**: Batch calls for emergency actions
3. **System Integrity**: Maintains user position during interventions

### Emergency Features:
- Atomic batch operations
- Schedule merging capabilities
- Fund recovery mechanisms
- System integrity preservation

## Treasury Integration

The treasury system integrates with vesting through:

1. **Atomic Operations**: Combined treasury spend and vesting creation
2. **Batch Processing**: Multiple operations in single transaction
3. **Automated Implementation**: Streamlined fund distribution

### Integration Features:
- Atomic treasury spend + vesting creation
- Batch call processing
- Automated fund management
- Integrated tracking systems

## Implementation Details

### Vesting Schedule Configuration
```rust
VestingInfo::new(
    amount,           // Total amount to vest
    per_block,        // Amount unlocked per block
    start_block      // Starting block number
)
```

### Governance Integration
```rust
// Two-stage process example
let treasury_call = RuntimeCall::TreasuryPallet(pallet_treasury::Call::spend {
    asset_kind: Box::new(()),
    amount: grant_amount,
    beneficiary: Box::new(MultiAddress::Id(beneficiary)),
    valid_from: None,
});

let vesting_call = RuntimeCall::Vesting(pallet_vesting::Call::vested_transfer {
    target: MultiAddress::Id(beneficiary),
    schedule: vesting_info,
});
```

## Best Practices

1. **Grant Planning**
   - Define clear milestones
   - Set appropriate vesting periods
   - Consider technical complexity

2. **Implementation**
   - Use atomic operations where possible
   - Implement proper error handling
   - Maintain system integrity

3. **Monitoring**
   - Track vesting schedules
   - Monitor milestone completion
   - Maintain audit trail

4. **Emergency Procedures**
   - Define clear intervention criteria
   - Implement atomic operations
   - Preserve user positions

## Security Considerations

1. **Access Control**
   - Technical Collective authority
   - Treasury council permissions
   - Emergency intervention rights

2. **Transaction Safety**
   - Atomic operations
   - Batch processing
   - Error handling

3. **Fund Protection**
   - Vesting schedules
   - Milestone verification
   - Emergency procedures 