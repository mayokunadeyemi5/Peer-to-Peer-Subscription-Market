# 🎵 Peer-to-Peer Subscription Market

A decentralized marketplace for digital content creators to sell subscriptions to their digital goods (videos, templates, music) with token-gated access control powered by Clarity smart contracts on Stacks blockchain.

## ✨ Features

- 🎨 **Content Creation**: Creators can upload and monetize digital content
- 💰 **Subscription Model**: Time-based access control with flexible pricing
- 🔐 **Token-Gated Access**: Blockchain-verified content access
- 📈 **Creator Earnings**: Transparent revenue tracking
- ⚡ **Flexible Subscriptions**: Purchase, extend, and manage subscriptions
- 🛡️ **Platform Fees**: Configurable platform revenue model

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new peer-to-peer-market
cd peer-to-peer-market
```

Copy the contract code into `contracts/Peer-to-Peer-Subscription-Market.clar`

## 📖 Usage

### For Content Creators

#### Create Content
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market create-content 
  "My Awesome Video" 
  "High quality tutorial content" 
  u1000000 
  "QmHash123...")
```

#### Update Pricing
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market update-content-price u1 u2000000)
```

#### Toggle Content Status
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market toggle-content-status u1)
```

### For Subscribers

#### Purchase Subscription
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market purchase-subscription u1 u1440)
```

#### Extend Subscription
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market extend-subscription u1 u720)
```

#### Check Access
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market can-access-content tx-sender u1)
```

### Read-Only Functions

#### Get Content Information
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market get-content-info u1)
```

#### Check Subscription Status
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market has-valid-subscription 'SP1... u1)
```

#### Calculate Costs
```clarity
(contract-call? .Peer-to-Peer-Subscription-Market calculate-subscription-cost u1 u1440)
```

## 🏗️ Contract Architecture

### Data Structures

- **content-items**: Stores content metadata and pricing
- **subscriptions**: Tracks user subscriptions and expiration
- **creator-earnings**: Monitors creator revenue

### Key Functions

- `create-content`: Upload new digital content
- `purchase-subscription`: Buy time-based access
- `extend-subscription`: Extend existing subscriptions
- `can-access-content`: Verify access permissions
- `get-creator-earnings`: Track creator revenue

## 💡 Pricing Model

- Subscriptions are priced per block (approximately 10 minutes per block)
- Base price is per ~24 hours (144 blocks)
- Platform takes configurable fee (default 5%)
- Creators receive remainder after platform fee

## 🧪 Testing

```bash
clarinet test
```

```bash
clarinet console
```

## 🔧 Configuration

### Platform Fee
Only contract owner can modify platform fee (max 20%):

```clarity
(contract-call? .Peer-to-Peer-Subscription-Market set-platform-fee u10)
```

## 📊 Error Codes

- `u100`: Not authorized
- `u101`: Already exists
- `u102`: Not found
- `u103`: Insufficient payment
- `u104`: Subscription expired
- `u105`: Invalid duration
- `u106`: Cannot subscribe to own content

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## 📄 License

MIT License - feel free to use for your projects!

## 🌟 Support

Star this repo if you find it useful! 

For questions or support, open an issue on GitHub.
```

**Git Commit Message:**
```
feat: implement peer-to-peer subscription marketplace with token-gated content access
```

**GitHub Pull Request Title:**
```
🎵 Add Peer-to-Peer Subscription Market Smart Contract
```

**GitHub Pull Request Description:**
```
## Summary
Added a complete peer-to-peer subscription marketplace smart contract that enables creators to monetize digital content through time-based subscriptions with blockchain-verified access control.

## Features Added
- ✅ Content creation and management system
- ✅ Time-based subscription purchasing and extension
- ✅ Token-gated access verification
- ✅ Creator earnings tracking
- ✅ Platform fee management
- ✅ Comprehensive read-only query functions

## Technical Details
- Built with Clarity smart contract language
- Uses Stacks blockchain block height for time-based subscriptions
- Implements secure STX payment handling
- Includes proper error
