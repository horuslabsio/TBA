////////////////////////////////
// Registry contract
////////////////////////////////
#[starknet::contract]
mod Registry {
    use token_bound_accounts::registry::RegistryComponent;

    component!(path: RegistryComponent, storage: registry, event: RegistryEvent);

    // Account
    #[abi(embed_v0)]
    impl RegistryImpl = RegistryComponent::RegistryImpl<ContractState>;
    impl AccountInternalImpl = RegistryComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        registry: RegistryComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RegistryEvent: RegistryComponent::Event
    }

}
