# VaultCoin Protocol

VaultCoin is an institutional-grade collateralized debt protocol built on the Stacks blockchain that enables users to generate synthetic assets through over-collateralized debt positions.

## Overview

VaultCoin represents a cutting-edge decentralized finance solution that transforms Bitcoin holdings into productive capital through sophisticated collateralization mechanics. The protocol implements dynamic interest rates, real-time liquidation engines, and oracle-based price feeds to maintain system stability while maximizing capital efficiency.

## Key Features

- **Over-collateralized Positions**: Create synthetic USD-pegged tokens backed by BTC collateral
- **Dynamic Interest Rates**: Interest accrual system with ~10% APR baseline
- **Automated Risk Management**: Real-time position monitoring and liquidation
- **Price Oracle Integration**: Secure price feeds with 24-hour validity window
- **Emergency Controls**: Protocol pause mechanism for risk mitigation

## Core Parameters

- Minimum Collateral Ratio: 150%
- Liquidation Threshold: 120%
- Liquidation Penalty: 10%
- Minimum Loan Amount: 100 tokens (8 decimal precision)
- Price Feed Expiry: 24 hours
- Interest Rate: 0.0005% per block (~10% APR)

## Smart Contract Functions

### User Operations

- `create-position`: Open or expand a collateralized debt position
- `add-collateral`: Increase position collateral
- `repay-debt`: Reduce outstanding debt
- `withdraw-collateral`: Remove excess collateral
- `liquidate-position`: Liquidate unsafe positions

### Administrative Functions

- `set-protocol-owner`: Transfer protocol ownership
- `pause-protocol`: Emergency protocol pause/unpause
- `update-btc-price`: Update price oracle feed

### Query Functions

- `get-position`: Retrieve position details
- `get-collateralization-ratio`: Calculate position safety ratio
- `get-protocol-stats`: View protocol metrics
- `get-current-price`: Get latest BTC price

## Security Features

1. Real-time collateral ratio monitoring
2. Price feed expiration checks
3. Liquidation incentives
4. Emergency pause mechanism
5. Administrative access controls

## Technical Architecture

The protocol is built using Clarity smart contracts on the Stacks blockchain, featuring:

- Fungible token implementation for synthetic USD
- Precise fixed-point arithmetic for financial calculations
- Event emission for position tracking
- Modular function design for upgradability
- Comprehensive error handling

## Development

### Prerequisites

- Clarinet
- Node.js
- Stacks CLI tools

### Testing

Run the test suite:

```bash
clarinet test
```

Check contract syntax and types:

```bash
clarinet check
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## Disclaimer

This protocol is provided "as is" without warranty of any kind. Users should exercise caution and understand the risks involved in DeFi protocols before participation.
