# ProposalRank - Governance Platform with Reputation System

A decentralized governance smart contract built on the Stacks blockchain using Clarity. ProposalRank tracks proposal success rates and maintains on-chain reputation scores to create a merit-based governance system.

## Features

### 🏛️ Governance System
- **Proposal Submission**: Users can submit governance proposals with titles and descriptions
- **Weighted Voting**: Vote with power based on reputation score
- **Time-bound Voting**: Configurable voting periods with automatic finalization
- **Proposal Execution**: Track and execute passed proposals

### 🏆 Reputation System
- **Success Rate Tracking**: Monitor proposal success rates for each user
- **Activity Rewards**: Bonus reputation points for voting participation
- **Dynamic Voting Power**: Voting influence increases with reputation
- **Transparent Scoring**: All reputation data stored on-chain

## Contract Architecture

### Data Structures

#### Proposals
```clarity
{
  proposer: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  votes-for: uint,
  votes-against: uint,
  start-block: uint,
  end-block: uint,
  status: uint,
  executed: bool
}
```

#### User Reputation
```clarity
{
  total-proposals: uint,
  successful-proposals: uint,
  reputation-score: uint,
  total-votes-cast: uint
}
```

### Proposal States
- `PROPOSAL_PENDING` (0): Initial state
- `PROPOSAL_ACTIVE` (1): Open for voting
- `PROPOSAL_PASSED` (2): Voting ended, proposal passed
- `PROPOSAL_FAILED` (3): Voting ended, proposal failed
- `PROPOSAL_EXECUTED` (4): Passed proposal has been executed

## Core Functions

### Public Functions

#### `submit-proposal`
```clarity
(submit-proposal (title (string-ascii 100)) (description (string-ascii 500)))
```
Submit a new governance proposal. Automatically increments the user's total proposal count.

**Parameters:**
- `title`: Brief proposal title (max 100 characters)
- `description`: Detailed proposal description (max 500 characters)

**Returns:** `(ok proposal-id)` on success

#### `vote-on-proposal`
```clarity
(vote-on-proposal (proposal-id uint) (vote-for bool))
```
Cast a weighted vote on an active proposal.

**Parameters:**
- `proposal-id`: The ID of the proposal to vote on
- `vote-for`: `true` for yes, `false` for no

**Requirements:**
- Voting period must be active
- User cannot vote twice on the same proposal

**Returns:** `(ok true)` on success

#### `finalize-proposal`
```clarity
(finalize-proposal (proposal-id uint))
```
Determine the outcome of a proposal after voting ends. Updates proposer's reputation if proposal passes.

**Parameters:**
- `proposal-id`: The ID of the proposal to finalize

**Requirements:**
- Voting period must have ended
- Proposal must be in ACTIVE state

**Returns:** `(ok true/false)` indicating if proposal passed

#### `execute-proposal`
```clarity
(execute-proposal (proposal-id uint))
```
Mark a passed proposal as executed.

**Parameters:**
- `proposal-id`: The ID of the proposal to execute

**Requirements:**
- Proposal must have passed
- Proposal must not already be executed

### Read-Only Functions

#### `get-proposal`
Get complete proposal details by ID.

#### `get-user-reputation`
Get reputation data for a specific user.

#### `calculate-reputation`
Calculate current reputation score for a user.
- **Formula**: `(successful_proposals / total_proposals) × 100 + (total_votes_cast / 10)`

#### `get-voting-power`
Get current voting power for a user.
- **Formula**: `1 + (reputation_score / 10)`

#### `is-voting-ended`
Check if voting period has ended for a proposal.

#### `has-user-voted`
Check if a user has already voted on a specific proposal.

## Reputation System Details

### Scoring Algorithm
The reputation system balances proposal success with voting participation:

1. **Base Score**: Success rate percentage (successful proposals ÷ total proposals × 100)
2. **Activity Bonus**: Voting participation bonus (total votes ÷ 10)
3. **Voting Power**: Base power (1) + reputation bonus (score ÷ 10)

### Example Reputation Calculation
```
User A: 8 successful proposals out of 10 total, 50 votes cast
Base Score: (8/10) × 100 = 80 points
Activity Bonus: 50/10 = 5 points
Total Reputation: 80 + 5 = 85 points
Voting Power: 1 + (85/10) = 9.5 ≈ 9 votes
```

## Deployment Guide

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for deployment

### Setup
```bash
# Clone the project
git clone <your-repo>
cd proposal-rank

# Check contract syntax
clarinet check

# Run tests
npm install
npm test

# Deploy to testnet
clarinet deploy --testnet
```

### Configuration
The contract owner can configure:
- **Voting Period**: Default 1440 blocks (~10 days)
- **Initial Voting Power**: Bootstrap power for early users

## Usage Examples

### Submit a Proposal
```clarity
(contract-call? .proposal-rank submit-proposal 
  "Increase Block Rewards" 
  "Proposal to increase mining rewards by 10% to incentivize network security")
```

### Vote on a Proposal
```clarity
;; Vote yes on proposal #1
(contract-call? .proposal-rank vote-on-proposal u1 true)
```

### Check Reputation
```clarity
;; Get reputation for a user
(contract-call? .proposal-rank get-user-reputation 'SP1ABC...)
```

## Security Features

- **Anti-Double Voting**: Users cannot vote twice on the same proposal
- **Time-Bound Voting**: Proposals have fixed voting windows
- **Access Control**: Admin functions restricted to contract owner
- **State Validation**: Proper checks for proposal states and transitions
- **Error Handling**: Comprehensive error codes and validation

## Error Codes

- `ERR_UNAUTHORIZED` (100): Access denied
- `ERR_PROPOSAL_NOT_FOUND` (101): Invalid proposal ID
- `ERR_PROPOSAL_ALREADY_EXISTS` (102): Duplicate proposal
- `ERR_PROPOSAL_ALREADY_EXECUTED` (103): Proposal already executed
- `ERR_VOTING_ENDED` (104): Voting period has ended
- `ERR_VOTING_NOT_ENDED` (105): Voting still active
- `ERR_ALREADY_VOTED` (106): User already voted

## Future Enhancements

- **Proposal Categories**: Different types of proposals with varying requirements
- **Quadratic Voting**: Alternative voting mechanisms
- **Delegation**: Allow users to delegate voting power
- **Treasury Integration**: Link proposals to treasury fund management
- **Multi-sig Execution**: Require multiple signatures for execution

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## License

MIT License - see LICENSE file for details
