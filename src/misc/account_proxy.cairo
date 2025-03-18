use starknet::{ContractAddress, account::Call};

#[starknet::interface]
pub trait IAccountProxy<TContractState> {
    fn execute(
        ref self: TContractState, contract_address: ContractAddress, calls: Array<Call>
    ) -> Array<Span<felt252>>;
}

// *************************************************************************
//               ACCOUNT PROXY - FOR SESSION MANAGEMENT (UNADUITED)
// *************************************************************************
#[starknet::contract]
pub mod AccountProxy {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use starknet::{ContractAddress, account::Call, get_caller_address};
    use token_bound_accounts::interfaces::{
        IExecutable::{IExecutableDispatcher, IExecutableDispatcherTrait},
        IAccount::{IAccountDispatcher, IAccountDispatcherTrait}
    };

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {}

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[abi(embed_v0)]
    impl AccountProxy of super::IAccountProxy<ContractState> {
        fn execute(
            ref self: ContractState, contract_address: ContractAddress, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            // access control - restrict `execute_by_proxy` to only account owner
            let caller = get_caller_address();
            let owner = IAccountDispatcher { contract_address: contract_address }.owner();
            assert(caller == owner, Errors::UNAUTHORIZED);

            // execute
            let dispatcher = IExecutableDispatcher { contract_address: contract_address };
            dispatcher.execute(calls)
        }
    }
}
