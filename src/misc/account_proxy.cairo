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
    use starknet::{ContractAddress, account::Call};
    use token_bound_accounts::interfaces::IExecutable::{
        IExecutableDispatcher, IExecutableDispatcherTrait
    };

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {}

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[abi(embed_v0)]
    impl AccountProxy of super::IAccountProxy<ContractState> {
        fn execute(
            ref self: ContractState, contract_address: ContractAddress, mut calls: Array<Call>
        ) -> Array<Span<felt252>> {
            let dispatcher = IExecutableDispatcher { contract_address: contract_address };
            dispatcher.execute(calls)
        }
    }
}
