#[starknet::component]
pub mod AccountComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::storage::StoragePointerReadAccess;
    use core::{
        result::ResultTrait, hash::HashStateTrait, pedersen::PedersenTrait, num::traits::zero::Zero
    };
    use starknet::{
        get_tx_info, get_contract_address, ContractAddress, account::Call,
        syscalls::call_contract_syscall, storage::StoragePointerWriteAccess
    };
    use token_bound_accounts::utils::array_ext::ArrayExt;
    use token_bound_accounts::interfaces::IAccount::{IAccount, TBA_INTERFACE_ID};

    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::introspection::src5::SRC5Component::{SRC5Impl, InternalImpl};

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    pub struct Storage {
        account_token_contract: ContractAddress, // contract address of NFT
        account_token_id: u256, // token ID of NFT
        context: Context, // account deployment details
        state: u256, // account state
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
    //                              STRUCTS
    // *************************************************************************
    #[derive(Copy, Drop, starknet::Store)]
    struct Context {
        registry: ContractAddress,
        implementation_hash: felt252,
        salt: felt252
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        pub const INV_SIG_LEN: felt252 = 'Account: invalid sig length';
        pub const INV_TX_VERSION: felt252 = 'Account: invalid tx version';
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(AccountImpl)]
    pub impl Account<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>
    > of IAccount<ComponentState<TContractState>> {
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
            get_dep_component!(self, SRC5).supports_interface(interface_id)
        }
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl AccountPrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>
    > of AccountPrivateTrait<TContractState> {
        /// @notice initializes the account by setting the initial token contract and token id
        fn initializer(
            ref self: ComponentState<TContractState>,
            token_contract: ContractAddress,
            token_id: u256,
            registry: ContractAddress,
            implementation_hash: felt252,
            salt: felt252
        ) {
            let owner = self._get_owner(token_contract, token_id);
            assert(owner.is_non_zero(), Errors::UNAUTHORIZED);

            // initialize account
            self.account_token_contract.write(token_contract);
            self.account_token_id.write(token_id);
            self.context.write(Context { registry, implementation_hash, salt });

            // register interfaces
            let IERC721_RECEIVER_ID =
                0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;
            let mut src5_instance = get_dep_component_mut!(ref self, SRC5);
            src5_instance.register_interface(TBA_INTERFACE_ID);
            src5_instance.register_interface(IERC721_RECEIVER_ID);

            // emit event
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

        /// @notice internal function to retrieve deployment details of an account
        fn _context(self: @ComponentState<TContractState>) -> (ContractAddress, felt252, felt252) {
            let context = self.context.read();
            (context.registry, context.implementation_hash, context.salt)
        }

        /// @notice internal function for checking if an account is a tokenbound account
        /// @param token_contract contract address of NFT
        /// @param token_id token ID of NFT
        fn _is_tokenbound_account(
            self: @ComponentState<TContractState>,
            account: ContractAddress,
            token_contract: ContractAddress,
            token_id: u256,
            registry: ContractAddress,
            implementation: felt252,
            salt: felt252
        ) -> bool {
            let constructor_calldata_hash = PedersenTrait::new(0)
                .update(token_contract.into())
                .update(token_id.low.into())
                .update(token_id.high.into())
                .update(registry.into())
                .update(implementation)
                .update(salt)
                .update(6)
                .finalize();

            let prefix: felt252 = 'STARKNET_CONTRACT_ADDRESS';
            let account_address = PedersenTrait::new(0)
                .update(prefix)
                .update(registry.into())
                .update(salt)
                .update(implementation)
                .update(constructor_calldata_hash)
                .update(5)
                .finalize();

            account_address.try_into().unwrap() == account
        }

        /// @notice internal transaction for returning the contract address and token ID of the NFT
        fn _get_token(self: @ComponentState<TContractState>) -> (ContractAddress, u256, felt252) {
            let contract = self.account_token_contract.read();
            let token_id = self.account_token_id.read();
            let tx_info = get_tx_info().unbox();
            let chain_id = tx_info.chain_id;
            (contract, token_id, chain_id)
        }

        /// @notice internal function for executing transactions
        /// @param calls An array of transactions to be executed
        fn _execute_calls(
            ref self: ComponentState<TContractState>, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            let mut result: Array<Span<felt252>> = ArrayTrait::new();
            let mut calls = calls;
            let mut index = 0;

            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        match call_contract_syscall(call.to, call.selector, call.calldata) {
                            Result::Ok(mut retdata) => {
                                result.append(retdata);
                                index += 1;
                            },
                            Result::Err(err) => {
                                let mut data = array!['multicall-failed', index];
                                data.append_all(err.span());
                                panic(data);
                            }
                        }
                    },
                    Option::None(_) => { break (); }
                };
            };
            result
        }
    }
}
