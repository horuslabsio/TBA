////////////////////////////////
// Account Component
////////////////////////////////
#[starknet::component]
mod AccountComponent {
    use starknet::{
        get_tx_info, get_caller_address, get_contract_address, get_block_timestamp, ContractAddress,
        account::Call, call_contract_syscall, replace_class_syscall, ClassHash, SyscallResultTrait
    };
    use ecdsa::check_ecdsa_signature;
    use array::{SpanTrait, ArrayTrait};
    use box::BoxTrait;
    use option::OptionTrait;
    use zeroable::Zeroable;
    use token_bound_accounts::interfaces::IERC721::{IERC721DispatcherTrait, IERC721Dispatcher};
    use token_bound_accounts::interfaces::IAccount::IAccount;
    use token_bound_accounts::interfaces::IAccount::{TBA_INTERFACE_ID};

    #[storage]
    struct Storage {
        Account_token_contract: ContractAddress, // contract address of NFT
        Account_token_id: u256, // token ID of NFT
        Account_unlock_timestamp: u64, // time to unlock account when locked
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountCreated: AccountCreated,
        AccountLocked: AccountLocked,
        TransactionExecuted: TransactionExecuted
    }

    /// @notice Emitted exactly once when the account is initialized
    /// @param owner The owner address
    #[derive(Drop, starknet::Event)]
    struct AccountCreated {
        #[key]
        owner: ContractAddress,
    }

    /// @notice Emitted when the account executes a transaction
    /// @param hash The transaction hash
    /// @param response The data returned by the methods called
    #[derive(Drop, starknet::Event)]
    struct TransactionExecuted {
        #[key]
        hash: felt252,
        response: Span<Span<felt252>>
    }

    /// @notice Emitted when the account is locked
    /// @param account tokenbound account who's lock function was triggered
    /// @param locked_at timestamp at which the lock function was triggered
    /// @param duration time duration for which the account remains locked
    #[derive(Drop, starknet::Event)]
    struct AccountLocked {
        #[key]
        account: ContractAddress,
        locked_at: u64,
        duration: u64,
    }

    mod Errors {
        const LOCKED_ACCOUNT: felt252 = 'Account: account is locked!';
        const INV_TX_VERSION: felt252 = 'Account: invalid tx version';
        const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        const INV_SIG_LEN: felt252 = 'Account: invalid sig length';
        const INV_SIGNATURE: felt252 = 'Account: invalid signature';
    }

    #[embeddable_as(AccountImpl)]
    impl Account<
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

        fn __validate_deploy__(
            self: @ComponentState<TContractState>,
            class_hash: felt252,
            contract_address_salt: felt252,
        ) -> felt252 {
            self._validate_transaction()
        }

        fn __validate_declare__(
            self: @ComponentState<TContractState>, class_hash: felt252
        ) -> felt252 {
            self._validate_transaction()
        }

        /// @notice validate an account transaction
        /// @param calls an array of transactions to be executed
        fn __validate__(
            ref self: ComponentState<TContractState>, mut calls: Array<Call>
        ) -> felt252 {
            self._validate_transaction()
        }

        /// @notice executes a transaction
        /// @param calls an array of transactions to be executed
        fn __execute__(
            ref self: ComponentState<TContractState>, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            self._assert_only_owner();
            let (lock_status, _) = self._is_locked();
            assert(!lock_status, Errors::LOCKED_ACCOUNT);

            let tx_info = get_tx_info().unbox();
            assert(tx_info.version != 0, Errors::INV_TX_VERSION);

            let retdata = self._execute_calls(calls);
            let hash = tx_info.transaction_hash;
            let response = retdata.span();
            self.emit(TransactionExecuted { hash, response });
            retdata
        }

        /// @notice gets the token bound NFT owner
        /// @param token_contract the contract address of the NFT
        /// @param token_id the token ID of the NFT
        fn owner(
            self: @ComponentState<TContractState>, token_contract: ContractAddress, token_id: u256
        ) -> ContractAddress {
            self._get_owner(token_contract, token_id)
        }

        /// @notice returns the contract address and token ID of the NFT
        fn token(self: @ComponentState<TContractState>) -> (ContractAddress, u256) {
            self._get_token()
        }

        // @notice protection mechanism for selling token bound accounts. can't execute when account is locked
        // @param duration for which to lock account
        fn lock(ref self: ComponentState<TContractState>, duration: u64) {
            self._assert_only_owner();
            let (lock_status, _) = self._is_locked();
            assert(!lock_status, Errors::LOCKED_ACCOUNT);
            let current_timestamp = get_block_timestamp();
            let unlock_time = current_timestamp + duration;
            self.Account_unlock_timestamp.write(unlock_time);
            self
                .emit(
                    AccountLocked {
                        account: get_contract_address(), locked_at: current_timestamp, duration
                    }
                );
        }

        // @notice returns account lock status and time left until account unlocks
        fn is_locked(self: @ComponentState<TContractState>) -> (bool, u64) {
            return self._is_locked();
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

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// @notice initializes the account by setting the initial token conrtact and token id
        fn initializer(
            ref self: ComponentState<TContractState>,
            token_contract: ContractAddress,
            token_id: u256
        ) {
            self.Account_token_contract.write(token_contract);
            self.Account_token_id.write(token_id);

            let owner = self._get_owner(token_contract, token_id);
            self.emit(AccountCreated { owner });
        }

        /// @notice check that caller is the token bound account
        fn _assert_only_owner(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            let owner = self
                ._get_owner(self.Account_token_contract.read(), self.Account_token_id.read());
            assert(caller == owner, Errors::UNAUTHORIZED);
        }

        /// @notice internal function for getting NFT owner
        /// @param token_contract contract address of NFT
        // @param token_id token ID of NFT
        // NB: This function aims for compatibility with all contracts (snake or camel case) but do not work as expected on mainnet as low level calls do not return err at the moment. Should work for contracts which implements CamelCase but not snake_case until starknet v0.15.
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
        fn _get_token(self: @ComponentState<TContractState>) -> (ContractAddress, u256) {
            let contract = self.Account_token_contract.read();
            let tokenId = self.Account_token_id.read();
            (contract, tokenId)
        }

        // @notice protection mechanism for TBA trading. Returns the lock-status (true or false), and the remaning time till account unlocks.
        fn _is_locked(self: @ComponentState<TContractState>) -> (bool, u64) {
            let unlock_timestamp = self.Account_unlock_timestamp.read();
            let current_time = get_block_timestamp();
            if (current_time < unlock_timestamp) {
                let time_until_unlocks = unlock_timestamp - current_time;
                return (true, time_until_unlocks);
            } else {
                return (false, 0_u64);
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

        /// @notice internal function for signature validation
        fn _is_valid_signature(
            self: @ComponentState<TContractState>, hash: felt252, signature: Span<felt252>
        ) -> felt252 {
            let signature_length = signature.len();
            assert(signature_length == 2_u32, Errors::INV_SIG_LEN);

            let caller = get_caller_address();
            let owner = self
                ._get_owner(self.Account_token_contract.read(), self.Account_token_id.read());
            if (caller == owner) {
                return starknet::VALIDATED;
            } else {
                return 0;
            }
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
                            Result::Err(_) => { panic_with_felt252('multicall_failed'); }
                        }
                    },
                    Option::None(_) => { break (); }
                };
            };
            result
        }
    }
}
