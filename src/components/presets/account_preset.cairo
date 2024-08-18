// *************************************************************************
//                              BASE ACCOUNT PRESET
// *************************************************************************
#[starknet::contract]
pub mod AccountPreset {
    use starknet::{ContractAddress, get_caller_address, ClassHash, account::Call};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::interfaces::{
        IUpgradeable::IUpgradeable,
        IExecutable::IExecutable,
    };

    component!(path: AccountComponent, storage: account, event: AccountEvent);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;

    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress, token_id: u256) {
        self.account.initializer(token_contract, token_id);
    }

    #[abi(embed_v0)]
    impl Executable of IExecutable<ContractState> {
        fn execute(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            self.account._execute(calls)
        }
    }

}