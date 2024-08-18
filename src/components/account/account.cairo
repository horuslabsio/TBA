// *************************************************************************
//                              ACCOUNT COMPONENT
// *************************************************************************
#[starknet::component]
pub mod AccountComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use core::result::ResultTrait;
    use core::hash::HashStateTrait;
    use core::pedersen::PedersenTrait;
    use core::num::traits::zero::Zero;
    use starknet::{
        get_tx_info, get_caller_address, get_contract_address, get_block_timestamp, ContractAddress,
        account::Call, syscalls::call_contract_syscall, syscalls::replace_class_syscall, ClassHash, SyscallResultTrait
    };
    use token_bound_accounts::interfaces::IERC721::{IERC721DispatcherTrait, IERC721Dispatcher};
    use token_bound_accounts::interfaces::IAccount::{
        IAccount, IAccountDispatcherTrait, IAccountDispatcher, TBA_INTERFACE_ID
    };

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
   pub struct Storage {
        account_token_contract: ContractAddress, // contract address of NFT
        account_token_id: u256, // token ID of NFT
        state: u256
    }

    // *************************************************************************
    //                              EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TBACreated: TBACreated,
        TransactionExecuted: TransactionExecuted
    }

    /// @notice Emitted exactly once when the account is initialized
    /// @param owner The owner address
    #[derive(Drop, starknet::Event)]
    pub struct TBACreated {
        #[key]
        pub account_address: ContractAddress,
        pub parent_account: ContractAddress,
        pub token_contract: ContractAddress,
        pub token_id: u256
    }

    /// @notice Emitted when the account executes a transaction
    /// @param hash The transaction hash
    /// @param response The data returned by the methods called
    #[derive(Drop, starknet::Event)]
    pub struct TransactionExecuted {
        #[key]
        pub hash: felt252,
        #[key]
        pub account_address: ContractAddress,
        pub response: Span<Span<felt252>>
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        pub const INV_SIG_LEN: felt252 = 'Account: invalid sig length';
        pub const INV_SIGNATURE: felt252 = 'Account: invalid signature';
        pub const INV_TX_VERSION: felt252 = 'Account: invalid tx version';
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(AccountImpl)]
    pub impl Account<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IAccount<ComponentState<TContractState>> {
        /// @notice used for signature validation
        /// @param hash The message hash
        /// @param signature The signature to be validated
        fn is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> felt252 {
            self._is_valid_signature(hash, signature)
        }

        /// @notice used to validate signer
        /// @param signer address to be validated
        fn is_valid_signer(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
           self._is_valid_signer(signer)
        }

        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252
        ) -> felt252 {
            self._validate_transaction()
        }

        /// @notice gets the NFT owner
        /// @param token_contract the contract address of the NFT
        /// @param token_id the token ID of the NFT
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            let token_contract = self.account_token_contract.read();
            let token_id = self.account_token_id.read();
            self._get_owner(token_contract, token_id)
        }

        /// @notice returns the contract address and token ID of the associated NFT
        fn token(self: @ComponentState<TContractState>) -> (ContractAddress, u256, felt252) {
            self._get_token()
        }

        /// @notice returns the current state of the account
        fn state(self: @ComponentState<TContractState>) -> u256 {
            self.state.read()
        }

        // @notice check that account supports TBA interface
        // @param interface_id interface to be checked against
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            if (interface_id == TBA_INTERFACE_ID) {
                return true;
            } else {
                return false;
            }
        }
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// @notice initializes the account by setting the initial token contract and token id
        fn initializer(
            ref self: ComponentState<TContractState>,
            token_contract: ContractAddress,
            token_id: u256
        ) {
            let owner = self._get_owner(token_contract, token_id);
            assert(owner.is_non_zero(), Errors::UNAUTHORIZED);
            // initialize account
            self.account_token_contract.write(token_contract);
            self.account_token_id.write(token_id);
            self
                .emit(
                    TBACreated {
                        account_address: get_contract_address(),
                        parent_account: owner,
                        token_contract,
                        token_id
                    }
                );
        }

        // @notice executes a transaction
        // @notice this should be called within an `execute` method in implementation contracts
        // @param calls an array of transactions to be executed
        fn _execute(
            ref self: ComponentState<TContractState>, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            // validate signer
            let caller = get_caller_address();
            assert(self._is_valid_signer(caller), Errors::UNAUTHORIZED);

            // update state
            self._update_state();

            // validate tx version
            let tx_info = get_tx_info().unbox();
            assert(tx_info.version != 0, Errors::INV_TX_VERSION);

            // execute calls and emit event
            let retdata = self._execute_calls(calls);
            let hash = tx_info.transaction_hash;
            let response = retdata.span();
            self
                .emit(
                    TransactionExecuted { hash, account_address: get_contract_address(), response }
                );
            retdata
        }

        // @notice updates the state of the account
        fn _update_state(ref self: ComponentState<TContractState>) {
            let tx_info = get_tx_info().unbox();
            let nonce = tx_info.nonce;
            let old_state = self.state.read();
            let new_state = PedersenTrait::new(old_state.try_into().unwrap())
                .update(nonce)
                .finalize();
            self.state.write(new_state.try_into().unwrap());
        }

        /// @notice internal function for getting NFT owner
        /// @param token_contract contract address of NFT
        // @param token_id token ID of NFT
        // NB: This function aims for compatibility with all contracts (snake or camel case) but do
        // not work as expected on mainnet as low level calls do not return err at the moment.
        // Should work for contracts which implements CamelCase but not snake_case until starknet
        // v0.15.
        fn _get_owner(
            self: @ComponentState<TContractState>, token_contract: ContractAddress, token_id: u256
        ) -> ContractAddress {
            let mut calldata: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@token_id, ref calldata);
            let mut res = call_contract_syscall(
                token_contract, selector!("ownerOf"), calldata.span()
            );
            if (res.is_err()) {
                res = call_contract_syscall(token_contract, selector!("owner_of"), calldata.span());
            }
            let mut address = res.unwrap();
            Serde::<ContractAddress>::deserialize(ref address).unwrap()
        }

        /// @notice internal transaction for returning the contract address and token ID of the NFT
        fn _get_token(self: @ComponentState<TContractState>) -> (ContractAddress, u256, felt252) {
            let contract = self.account_token_contract.read();
            let token_id = self.account_token_id.read();
            let tx_info = get_tx_info().unbox();
            let chain_id = tx_info.chain_id;
            (contract, token_id, chain_id)
        }

        // @notice internal function for validating signer
        fn _is_valid_signer(
            self: @ComponentState<TContractState>, signer: ContractAddress
        ) -> bool {
            let owner = self
                ._get_owner(self.account_token_contract.read(), self.account_token_id.read());
            if (signer == owner) {
                return true;
            } else {
                return false;
            }
        }

        /// @notice internal function for signature validation
        fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> felt252 {
            let signature_length = signature.len();
            assert(signature_length == 2_u32, Errors::INV_SIG_LEN);

            let owner = self
                ._get_owner(self.account_token_contract.read(), self.account_token_id.read());
            let account = IAccountDispatcher { contract_address: owner };
            if (account.is_valid_signature(hash, signature) == starknet::VALIDATED) {
                return starknet::VALIDATED;
            } else {
                return 0;
            }
        }

        /// @notice internal function for tx validation
        fn _validate_transaction(self: @ComponentState<TContractState>) -> felt252 {
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let signature = tx_info.signature;
            assert(
                self._is_valid_signature(tx_hash, signature) == starknet::VALIDATED,
                Errors::INV_SIGNATURE
            );
            starknet::VALIDATED
        }

        /// @notice internal function for executing transactions
        /// @param calls An array of transactions to be executed
        fn _execute_calls(
            ref self: ComponentState<TContractState>, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
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
