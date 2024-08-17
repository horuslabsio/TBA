// *************************************************************************
//                              EXECUTABLE COMPONENT
// *************************************************************************
#[starknet::component]
pub mod ExecutableComponent {
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, syscalls::call_contract_syscall,
        get_tx_info, SyscallResultTrait, account::Call
    };

    use token_bound_accounts::interfaces::IExecutable::IExecutable;
    use token_bound_accounts::components::account::account::AccountComponent;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    pub struct Storage {}

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TransactionExecuted: TransactionExecuted
    }

    /// @notice Emitted when the account executes a transaction
    /// @param hash The transaction hash
    /// @param response The data returned by the methods called
    #[derive(Drop, starknet::Event)]
    struct TransactionExecuted {
        #[key]
        hash: felt252,
        #[key]
        account_address: ContractAddress,
        response: Span<Span<felt252>>
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        pub const INV_TX_VERSION: felt252 = 'Account: invalid tx version';
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(ExecutableImpl)]
    impl Executable<
        TContractState, 
        +HasComponent<TContractState>, 
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>
    > of IExecutable<ComponentState<TContractState>> {
        /// @notice executes a transaction
        /// @notice whilst implementing this method, ensure to validate the signer by calling
        /// `is_valid_signer`.
        /// @param calls an array of transactions to be executed
        fn _execute(
            ref self: ComponentState<TContractState>, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            // let caller = get_caller_address();
            // let account_comp = get_dep_component!(@self, Account);
            // account_comp._is_valid_signer(caller);
            // assert(is_valid == 'VALID', Errors::UNAUTHORIZED);
            let tx_info = get_tx_info().unbox();
            assert(tx_info.version != 0, Errors::INV_TX_VERSION);

            let retdata = self._execute_calls(calls);
            let hash = tx_info.transaction_hash;
            let response = retdata.span();
            self
                .emit(
                    TransactionExecuted { hash, account_address: get_contract_address(), response }
                );
            retdata
        }
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl<
        TContractState, 
        +HasComponent<TContractState>, 
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
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
