# 🎭 Interactive Theater Script Voting

A decentralized voting platform for theater script selection built on the Stacks blockchain using Clarity smart contracts.

## 🌟 Overview

This smart contract enables theater communities to submit and vote on scripts in a transparent, decentralized manner. Authors can submit their scripts, and community members can vote to help determine which scripts should be produced.

## ✨ Key Features

- 📝 **Script Submission**: Authors can submit theater scripts with titles and descriptions
- 🗳️ **Democratic Voting**: Community members vote on submitted scripts
- ⏰ **Time-bound Voting**: Each script has a defined voting period
- 💰 **Submission Fee**: Small STX fee to prevent spam submissions
- 🚫 **Fair Voting**: Authors cannot vote on their own scripts
- 🔒 **One Vote Per Script**: Each user can vote only once per script
- 📊 **Transparent Results**: All voting data is publicly verifiable
- 🔧 **Flexible Management**: Authors can extend voting periods

## 🏗️ Contract Structure

### Constants
- **MIN_VOTING_PERIOD**: 144 blocks (~24 hours)
- **VOTING_FEE**: 1 STX (1,000,000 microSTX)
- **MAX_TITLE_LENGTH**: 100 characters
- **MAX_DESCRIPTION_LENGTH**: 500 characters

### Data Maps
- **Scripts**: Stores script metadata and voting information
- **Votes**: Tracks individual user votes
- **UserVoteCounts**: Counts votes per user per script
- **ScriptVoters**: Records voter participation timestamps

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet with STX for transactions

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Interactive-Theater-Script-Voting
```

2. Check contract compilation:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📋 Usage Guide

### For Script Authors 🖋️

#### Submit a Script
```clarity
(contract-call? .Interactive-Theater-Script-Voting submit-script 
  "Romeo and Juliet Reimagined" 
  "A modern take on Shakespeare's classic, set in contemporary NYC" 
  u1008) ;; voting duration in blocks
```

#### Extend Voting Period
```clarity
(contract-call? .Interactive-Theater-Script-Voting extend-voting 
  u1 ;; script-id
  u144) ;; additional blocks
```

#### Close Voting
```clarity
(contract-call? .Interactive-Theater-Script-Voting close-voting 
  u1) ;; script-id
```

### For Voters 🗳️

#### Vote for a Script
```clarity
(contract-call? .Interactive-Theater-Script-Voting vote-for-script 
  u1) ;; script-id
```

#### Check Voting Status
```clarity
(contract-call? .Interactive-Theater-Script-Voting get-voting-status 
  u1) ;; script-id
```

### For Everyone 👥

#### Get Script Details
```clarity
(contract-call? .Interactive-Theater-Script-Voting get-script-details 
  u1) ;; script-id
```

#### Check Vote Count
```clarity
(contract-call? .Interactive-Theater-Script-Voting get-script-vote-count 
  u1) ;; script-id
```

#### Get Contract Statistics
```clarity
(contract-call? .Interactive-Theater-Script-Voting get-contract-stats)
```

## 🔍 Read-Only Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `get-script-details` | Get complete script information | `script-id: uint` |
| `get-vote-status` | Check if a user voted on a script | `voter: principal, script-id: uint` |
| `get-voting-status` | Get voting status and remaining time | `script-id: uint` |
| `get-script-vote-count` | Get total votes for a script | `script-id: uint` |
| `has-user-voted` | Check if user has voted | `user: principal, script-id: uint` |
| `is-voting-active` | Check if voting is currently active | `script-id: uint` |
| `get-current-block` | Get current block height | - |
| `get-contract-stats` | Get overall contract statistics | - |

## ⚠️ Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-NOT-AUTHORIZED | User not authorized for this action |
| 101 | ERR-SCRIPT-NOT-FOUND | Script ID does not exist |
| 102 | ERR-ALREADY-VOTED | User has already voted on this script |
| 103 | ERR-VOTING-CLOSED | Voting period has ended |
| 104 | ERR-VOTING-NOT-STARTED | Voting has not begun yet |
| 105 | ERR-INVALID-SCRIPT-ID | Invalid script identifier |
| 106 | ERR-SCRIPT-EXISTS | Script already exists |
| 107 | ERR-INVALID-TITLE | Title is empty or too long |
| 108 | ERR-INVALID-DESCRIPTION | Description is empty or too long |
| 109 | ERR-VOTING-PERIOD-TOO-SHORT | Voting period below minimum |
| 110 | ERR-CANNOT-VOTE-OWN-SCRIPT | Authors cannot vote on their own scripts |

## 🔐 Security Features

- ✅ **Ownership Verification**: Only script authors can extend voting or close early
- ✅ **Vote Uniqueness**: Prevents double voting through map-based tracking
- ✅ **Input Validation**: Validates title and description lengths
- ✅ **Time Constraints**: Enforces minimum voting periods
- ✅ **Fee Mechanism**: Reduces spam through submission fees
- ✅ **Self-Vote Prevention**: Authors cannot vote on their own scripts

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Run specific test:
```bash
clarinet test --filter test-name
```

## 🌐 Deployment

### Testnet Deployment
```bash
clarinet integrate
```

### Mainnet Deployment
1. Update `Clarinet.toml` for mainnet
2. Deploy using Clarinet or Stacks CLI
3. Verify contract deployment

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support, please open an issue on GitHub or contact the development team.

## 🎯 Roadmap

- [ ] Multi-round voting system
- [ ] Script categorization
- [ ] Reputation system for voters
- [ ] Integration with IPFS for script storage
- [ ] Mobile-friendly web interface
- [ ] Advanced analytics dashboard

---

**Built with ❤️ for the theater community on Stacks blockchain** 🎭

# Interactive Theater Script Voting

