# Component Signatory

<!-- logo -->
<p align="center">
  <img width='200' src="https://1330392220-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Ft2nl6Q0J1Gip9JKyMW79%2Fuploads%2FLKtcg1GIyT3yDkZm4bau%2Fstarknet.svg?alt=media&token=58e39f1a-aa1a-47c6-b850-24f40b4671f1">
</p>

<!-- primary badges -->
<p align="center">
  <a href="https://github.com/horuslabsio/TBA-SDK/LICENSE/">
    <img src="https://img.shields.io/badge/license-MIT-black">
  </a>
</p>



## Purpose of the Component Signatory

The contract is designed to validate a user that signs its identity. It checks whether a signer (a user or contract address) is authorized to interact with or perform actions on an account, ensuring that specific entities such as the NFT owner or other permissioned addresses can sign or approve actions.

Relation to ERC-6551
ERC-6551 introduces a system where every NFT is assigned a wallet address, allowing NFTs to own assets, interact with decentralized applications, and act as independent agents. This component integrates with ERC-6551 by validating the ownership of the NFT and ensuring that any actions performed are authenticated by the wallet assigned to the NFT, or by a permissioned address.

Seamless Interaction: ERC-6551 operates without requiring changes to existing NFT smart contracts. The Component Signatory checks whether a signer is either the NFT owner or a permissioned entity.

## Components and Structure
The contract interacts with various components and libraries, aligning closely with the principles of ERC-6551:

AccountComponent: Manages the account, which could be tied to the wallet address assigned to the NFT through ERC-6551.
PermissionableComponent: Handles permissioning, allowing specific addresses, such as the ERC-6551 wallet, to act on behalf of the NFT.
ISRC6Dispatcher: This component validates the signature using the ISRC6 standard, ensuring compatibility and secure signature validation across different interfaces, including ERC-6551-compliant contracts.

## Functions 

### Signer Validation 
_base_signer_validation: Validates the NFT owner's wallet address, assigned under ERC-6551, ensuring it is a legitimate signer.
```
fn _base_signer_validation(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let account = get_dep_component!(self, Account);
            let owner = account.owner();

            // validate
            if (signer == owner) {
                return true;
            } else {
                return false;
            }
        }
```

### _permissioned_signer_validation
Extends functionality to include permissioned addresses, allowing ERC-6551 wallet holders or other authorized entities to act on behalf of the NFT owner.
```
 fn _permissioned_signer_validation(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let account = get_dep_component!(self, Account);
            let owner = account.owner();

            // check if signer has permissions
            let permission = get_dep_component!(self, Permissionable);
            let is_permissioned = permission._has_permission(owner, signer);

            // validate
            if (signer == owner) {
                return true;
            } else if (is_permissioned) {
                return true;
            } else {
                return false;
            }
        }
```

### _is_valid_signature

This function checks whether a given digital signature is valid. It first verifies the signature's length and then interacts with the ISRC6Dispatcher to determine whether the provided signature matches the expected value. If the validation is successful, it returns VALIDATED; otherwise, it throws an INVALID_SIGNATURE error.

```
 fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> felt252 {
            let account = get_dep_component!(self, Account);
            let owner = account.owner();

            // validate signature length
            let signature_length = signature.len();
            assert(signature_length == 2_u32, Errors::INV_SIG_LEN);

            // validate
            let owner_account = ISRC6Dispatcher { contract_address: owner };
            if (owner_account.is_valid_signature(hash, signature) == starknet::VALIDATED) {
                return starknet::VALIDATED;
            } else {
                return Errors::INVALID_SIGNATURE;
            }
        }
``` 

## Error Handling
INV_SIG_LEN: Triggered for invalid signature length.
UNAUTHORIZED: Triggered for unauthorized signers, ensuring only the NFT owner or permissioned entities can sign.
INVALID_SIGNATURE: Triggered when the signature does not match the expected value from the ERC-6551-compliant wallet.

## Files for Reference

Link to existing documentation: https://docs.tbaexplorer.com/starknet-tokenbound-sdk/introduction-to-tokenbound
Link to the code: https://github.com/horuslabsio/TBA/blob/v3/src/components/signatory/signatory.cairo

