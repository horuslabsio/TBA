////////////////////////////////
// Registry contract
////////////////////////////////
#[starknet::contract]
mod Registry {
    use starknet::ClassHash;
    use token_bound_accounts::registry::RegistryComponent;
    use token_bound_accounts::upgradeable::UpgradeableComponent;
    use token_bound_accounts::interfaces::IUpgradeable::IUpgradeable;

    component!(path: RegistryComponent, storage: registry, event: RegistryEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Account
    #[abi(embed_v0)]
    impl RegistryImpl = RegistryComponent::RegistryImpl<ContractState>;
    impl AccountInternalImpl = RegistryComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registry: RegistryComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RegistryEvent: RegistryComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[external(v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.upgradeable._upgrade(new_class_hash);
        }
    }  

}
