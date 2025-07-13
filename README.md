# Tokenized Community Skill Sharing Platform

A decentralized platform built on Stacks blockchain that enables community members to share skills, verify expertise, coordinate teaching, track progress, and facilitate payments through smart contracts.

## Overview

This platform consists of five interconnected smart contracts that work together to create a comprehensive skill-sharing ecosystem:

### Core Contracts

1. **Expertise Verification Contract** (`expertise-verification.clar`)
    - Validates professional and hobby skill credentials
    - Manages skill categories and verification levels
    - Tracks verified experts and their specializations

2. **Teaching Coordination Contract** (`teaching-coordination.clar`)
    - Matches skill teachers with interested learners
    - Manages teaching sessions and scheduling
    - Handles teacher-learner relationships

3. **Progress Tracking Contract** (`progress-tracking.clar`)
    - Monitors learning outcomes and skill development
    - Tracks completion rates and milestones
    - Manages learning achievements and badges

4. **Payment Processing Contract** (`payment-processing.clar`)
    - Handles compensation for skill-sharing services
    - Manages escrow for teaching sessions
    - Processes payments and refunds

5. **Community Building Contract** (`community-building.clar`)
    - Facilitates ongoing relationships and knowledge exchange
    - Manages community reputation and ratings
    - Handles community governance and rewards

## Features

- **Decentralized Skill Verification**: Peer-to-peer validation of skills and expertise
- **Smart Matching**: Algorithm-based teacher-learner pairing
- **Progress Tracking**: Comprehensive learning analytics and milestone tracking
- **Secure Payments**: Escrow-based payment system with dispute resolution
- **Community Governance**: Token-based voting and reputation system
- **Reputation System**: Multi-dimensional rating and feedback mechanism

## Token Economics

The platform uses a native token (SKILL) for:
- Payment for teaching services
- Staking for expertise verification
- Governance voting rights
- Community rewards and incentives

## Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet configured
- Node.js for running tests

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts: \`clarinet deploy\`

### Usage

1. **For Teachers**: Register skills, get verified, create teaching sessions
2. **For Learners**: Browse skills, book sessions, track progress
3. **For Community**: Participate in governance, provide feedback, earn rewards

## Contract Architecture

Each contract is designed to be modular and secure:
- Input validation on all public functions
- Access control for administrative functions
- Event logging for transparency
- Error handling with descriptive codes

## Testing

Comprehensive test suite using Vitest covering:
- Contract deployment and initialization
- Core functionality testing
- Edge cases and error conditions
- Integration scenarios

## Security Considerations

- All user inputs are validated
- Access controls prevent unauthorized actions
- Funds are held in secure escrow
- Emergency pause functionality for critical issues

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
