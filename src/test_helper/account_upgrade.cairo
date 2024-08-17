use starknet::{account::Call, ContractAddress, ClassHash};

#[starknet::interface]
trait IUpgradedAccount<TContractState> {
    fn get_public_key(self: @TContractState) -> felt252;
    fn set_public_key(ref self: TContractState, new_public_key: felt252);
    fn isValidSignature(self: @TContractState, hash: felt252, signature: Span<felt252>) -> bool;
    fn __validate__(ref self: TContractState, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @TContractState, class_hash: felt252) -> felt252;
    fn __validate_deploy__(
        ref self: TContractState,
        _public_key: felt252,
        token_contract: ContractAddress,
        token_id: u256
    ) -> felt252;
    fn __execute__(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn token(self: @TContractState) -> (ContractAddress, u256);
    fn owner(
        ref self: TContractState, token_contract: ContractAddress, token_id: u256
    ) -> ContractAddress;
    fn upgrade(ref self: TContractState, implementation: ClassHash);
    fn version(self: @TContractState) -> u8;
}

#[starknet::interface]
trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    // IERC721Metadata
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;
}

#[starknet::contract(account)]
pub mod UpgradedAccount {
    use starknet::storage::StoragePointerWriteAccess;
use starknet::storage::StoragePointerReadAccess;
use starknet::{
        get_tx_info, get_caller_address, get_contract_address, ContractAddress, account::Call,
        syscalls::call_contract_syscall, syscalls::replace_class_syscall, ClassHash, SyscallResultTrait
    };
    use core::ecdsa::check_ecdsa_signature;
    use core::num::traits::zero::Zero;
    use super::{IERC721DispatcherTrait, IERC721Dispatcher};

    #[storage]
    struct Storage {
        _public_key: felt252,
        _token_contract: ContractAddress,
        _token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        tokenContract: ContractAddress,
        tokenId: u256,
        implementation: ClassHash
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _public_key: felt252,
        token_contract: ContractAddress,
        token_id: u256
    ) {
        self._public_key.write(_public_key);
        self._token_contract.write(token_contract);
        self._token_id.write(token_id);
    }


    #[abi(embed_v0)]
    impl IAccountImpl of super::IUpgradedAccount<ContractState> {
        fn get_public_key(self: @ContractState) -> felt252 {
            self._public_key.read()
        }

        fn set_public_key(ref self: ContractState, new_public_key: felt252) {
            self.assert_only_self();
            self._public_key.write(new_public_key);
        }

        fn isValidSignature(self: @ContractState, hash: felt252, signature: Span<felt252>) -> bool {
            self.is_valid_signature(hash, signature)
        }

        fn __validate_deploy__(
            ref self: ContractState,
            _public_key: felt252,
            token_contract: ContractAddress,
            token_id: u256
        ) -> felt252 {
            self.validate_transaction()
        }

        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            self.validate_transaction()
        }

        fn __validate__(ref self: ContractState, mut calls: Array<Call>) -> felt252 {
            self.validate_transaction()
        }

        fn __execute__(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            let caller = get_caller_address();
            assert(caller.is_zero(), 'invalid caller');

            let tx_info = get_tx_info().unbox();
            assert(tx_info.version != 0, 'invalid tx version');

            self._execute_calls(calls)
        }

        fn owner(
            ref self: ContractState, token_contract: ContractAddress, token_id: u256
        ) -> ContractAddress {
            IERC721Dispatcher { contract_address: token_contract }.owner_of(token_id)
        }

        fn token(self: @ContractState) -> (ContractAddress, u256) {
            let contract = self._token_contract.read();
            let tokenId = self._token_id.read();
            return (contract, tokenId);
        }

        fn upgrade(ref self: ContractState, implementation: ClassHash) {
            self.assert_only_self();
            assert(!implementation.is_zero(), 'Invalid class hash');
            replace_class_syscall(implementation).unwrap_syscall();
            self
                .emit(
                    Upgraded {
                        tokenContract: self._token_contract.read(),
                        tokenId: self._token_id.read(),
                        implementation,
                    }
                );
        }

        fn version(self: @ContractState) -> u8 {
            1_u8
        }
    }

    #[generate_trait]
    impl internalImpl of InternalTrait {
        fn assert_only_self(ref self: ContractState) {
            let caller = get_caller_address();
            let self = get_contract_address();
            assert(self == caller, 'Account: unathorized');
        }

        fn validate_transaction(self: @ContractState) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(self.is_valid_signature(tx_hash, signature), 'Account: invalid signature');
            starknet::VALIDATED
        }

        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Span<felt252>
        ) -> bool {
            let valid_length = signature.len() == 2_u32;
            let public_key = self._public_key.read();

            if valid_length {
                check_ecdsa_signature(
                    message_hash: hash,
                    public_key: public_key,
                    signature_r: *signature[0_u32],
                    signature_s: *signature[1_u32],
                )
            } else {
                false
            }
        }

        fn _execute_calls(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            let mut result: Array<Span<felt252>> = ArrayTrait::new();
            let mut calls = calls;

            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        match call_contract_syscall(call.to, call.selector, call.calldata) {
                            Result::Ok(mut retdata) => { result.append(retdata); },
                            Result::Err(_) => { panic(array!['multicall_failed']); }
                        }
                    },
                    Option::None(_) => { break (); }
                };
            };
            result
        }
    }
}
