// *************************************************************************
//                              BASE ACCOUNT PRESET
// *************************************************************************
use starknet::account::Call;

#[starknet::interface]
trait IAccountPreset<TState> {
    fn __execute__(ref self: TState, calls: Array<Call>) -> Array<Span<felt252>>;
}

#[starknet::contract(account)]
pub mod AccountPreset {
    use starknet::{ContractAddress, get_caller_address, ClassHash, account::Call};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::executable::executable::ExecutableComponent;
    use token_bound_accounts::interfaces::IUpgradeable::IUpgradeable;

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: ExecutableComponent, storage: executable, event: ExecutableEvent);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;

    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;
    impl ExecutableImpl = ExecutableComponent::ExecutableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        executable: ExecutableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        ExecutableEvent: ExecutableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress, token_id: u256) {
        self.account.initializer(token_contract, token_id);
    }

    #[abi(embed_v0)]
    impl AccountPreset of super::IAccountPreset<ContractState> {
        fn __execute__(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            self.executable._execute(calls)
        }
    }

}