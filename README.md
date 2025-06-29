# Festdao - Community Celebration DAO

A transparent decentralized autonomous organization for community event planning and budget management on the Stacks blockchain.

## Overview

Festdao enables communities to collectively plan celebrations, manage budgets, and track expenses in a fully transparent manner. Members can propose events, vote on budget allocations, and monitor fund usage through smart contract governance.

## Features

- **Member Management**: Join as a community member and build reputation through contributions
- **Event Creation**: Propose community celebrations with detailed descriptions and budget requests
- **Democratic Voting**: Vote on budget proposals using reputation-weighted governance
- **Budget Tracking**: Transparent fund allocation and expense management
- **Treasury Management**: Community-funded treasury with contribution tracking
- **Expense Approval**: Multi-step approval process for event expenses

## Contract Functions

### Member Functions

#### `become-member()`
Join the DAO as a new member with initial reputation of 1.

#### `contribute-to-treasury(amount)`
Contribute STX to the community treasury and increase your reputation.
- `amount`: Amount of microSTX to contribute

### Event Management

#### `create-event(name, description, budget-requested, event-date)`
Create a new community event proposal.
- `name`: Event name (max 100 characters)
- `description`: Event description (max 500 characters)
- `budget-requested`: Requested budget in microSTX
- `event-date`: Planned event date (block height)

#### `join-event(event-id)`
Join an approved event as a participant.
- `event-id`: ID of the event to join

#### `complete-event(event-id)`
Mark an event as completed (only event creator or contract owner).
- `event-id`: ID of the event to complete

### Governance

#### `create-budget-proposal(event-id, amount, description)`
Create a budget proposal for an event.
- `event-id`: ID of the target event
- `amount`: Requested amount in microSTX
- `description`: Proposal description (max 300 characters)

#### `vote-on-proposal(proposal-id, vote-for)`
Vote on a budget proposal using your reputation weight.
- `proposal-id`: ID of the proposal
- `vote-for`: true for yes, false for no

#### `finalize-proposal(proposal-id)`
Finalize voting on a proposal after voting period ends.
- `proposal-id`: ID of the proposal to finalize

### Expense Management

#### `add-expense(event-id, expense-id, description, amount, recipient)`
Add an expense to an event (event creator or contract owner only).
- `event-id`: ID of the target event
- `expense-id`: Unique expense identifier
- `description`: Expense description (max 200 characters)
- `amount`: Expense amount in microSTX
- `recipient`: Principal to receive the funds

#### `approve-expense(event-id, expense-id)`
Approve an expense for payment (event creator or contract owner only).
- `event-id`: ID of the target event
- `expense-id`: ID of the expense to approve

### Read-Only Functions

- `get-event(event-id)`: Get event details
- `get-proposal(proposal-id)`: Get proposal details
- `get-member-reputation(member)`: Get member's reputation score
- `is-member(address)`: Check if address is a member
- `get-treasury-balance()`: Get current treasury balance
- `get-expense(event-id, expense-id)`: Get expense details
- `get-participant-info(event-id, participant)`: Get participant information
- `get-vote(proposal-id, voter)`: Get vote details
- `get-next-event-id()`: Get next available event ID
- `get-next-proposal-id()`: Get next available proposal ID

## Usage Flow

1. **Join the DAO**: Call `become-member()` to become a community member
2. **Fund Treasury**: Use `contribute-to-treasury()` to add funds and build reputation
3. **Propose Event**: Create events with `create-event()` including budget requests
4. **Create Budget Proposal**: Use `create-budget-proposal()` to request funds for approved events
5. **Vote**: Members vote on proposals using `vote-on-proposal()`
6. **Finalize**: After voting period, call `finalize-proposal()` to execute results
7. **Manage Expenses**: Track event costs with `add-expense()` and `approve-expense()`
8. **Complete Events**: Mark successful events as complete with `complete-event()`

## Error Codes

- `u401`: Unauthorized - not a member or insufficient permissions
- `u404`: Not found - resource doesn't exist
- `u400`: Invalid amount - amount must be greater than 0
- `u409`: Already exists - duplicate entry
- `u402`: Insufficient funds - not enough treasury balance
- `u403`: Already voted - member has already voted on this proposal
- `u405`: Voting closed - voting period has ended
- `u406`: Event not active - event is not in the correct state

## Constants

- Minimum voting period: 144 blocks (approximately 24 hours)
- Initial member reputation: 1
- Reputation bonus for event completion: 2
- Reputation bonus for treasury contribution: 1

## Testing

Deploy the contract using Clarinet and test with the provided test suite:

```bash
clarinet test
```

## Security Considerations

- Only members can create events and vote on proposals
- Budget approvals require majority vote weighted by reputation
- Expenses require approval from event creators or contract owner
- Treasury contributions are tracked and increase member reputation
- All transactions are transparent and auditable on-chain
