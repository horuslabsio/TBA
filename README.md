# ERC-6551 Implementation on Starknet (SNIP-14)

This repository contains the reference implementation of ERC-6551 on Starknet.

**NB:** This project is under active development and may undergo changes until [SNIP-14](https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-14.md) is finalized. 

## The Tokenbound Standard
This proposal defines a system which assigns contract accounts to Non-fungible tokens (ERC-721s).

These accounts are referred to as token bound accounts and they allow NFTs to own assets and interact with applications, without requiring changes to existing smart contracts or infrastructure.

For more information, you could reference the [original EIP](https://eips.ethereum.org/EIPS/eip-6551) proposed by Jayden Windle and Benny Giang.

## Repository Structure
<img width='100%' src="https://eips.ethereum.org/assets/eip-6551/diagram.png" />

This Repository contains reference implementation of:
1. A singleton registry contract
2. An account contract

### The Registry Contract
The registry serves as a single entry point for all token bound account address queries. It has two key functions:

1. **create_account** - creates the token bound account for an NFT given an `implementation_hash`, `token_contract`, `token_id`, `salt` and `chain_id`.

2. **get_account** - computes the token bound account address for an NFT given an `implementation_hash`, `token_contract`, `token_id`, `salt` and `chain_id`.

### The Account Contract
The `accountV3` Contract provides a reference implementation for a TBA. Thanks to native account abstraction on Starknet, It's made up of different plug'n'play components. You can build your own account implementation using the available components.

## Development Setup
You will need to have Scarb and Starknet Foundry installed on your system. Refer to the documentations below:

- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/index.html)
- [Scarb](https://docs.swmansion.com/scarb/download.html)

To use this repository, first clone it:
```
git clone git@github.com:horuslabsio/TBA.git
cd TBA
```

### Building contracts
To build the contracts, run the command:
```
scarb build
```

### Running Tests
To run the tests contained within the `tests` folder, run the command:
```
snforge test
```

For more information on writing and running tests, refer to the [Starknet-Foundry documentation](https://foundry-rs.github.io/starknet-foundry/index.html)
