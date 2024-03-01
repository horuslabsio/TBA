////////////////////////////////
// Account contract
////////////////////////////////
#[starknet::contract(account)]
mod Account {
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use token_bound_accounts::account::AccountComponent;
    use token_bound_accounts::upgradeable::UpgradeableComponent;
    use token_bound_accounts::interfaces::IUpgradeable::IUpgradeable;

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress, token_id: u256) {
        self.account.initializer(token_contract, token_id);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.account._assert_only_owner();
            let (lock_status, _) = self.account._is_locked();
            assert(!lock_status, AccountComponent::Errors::LOCKED_ACCOUNT);
            self.upgradeable._upgrade(new_class_hash);
        }
    }
}
