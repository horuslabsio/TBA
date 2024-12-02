#[starknet::component]
pub mod UpgradeableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::{ClassHash, SyscallResultTrait, get_contract_address, ContractAddress};
    use core::num::traits::zero::Zero;

    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::account::account::AccountComponent::AccountPrivateImpl;

    use openzeppelin_introspection::src5::SRC5Component;

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
        TBAUpgraded: TBAUpgraded
    }

    /// @notice Emitted when the contract is upgraded.
    /// @param class_hash implementation hash to be upgraded to
    #[derive(Drop, starknet::Event)]
    pub struct TBAUpgraded {
        pub account_address: ContractAddress,
        pub class_hash: ClassHash
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl UpgradeablePrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>
    > of UpgradeablePrivateTrait<TContractState> {
        /// @notice replaces the contract's class hash with `new_class_hash`.
        /// Emits an `Upgraded` event.
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            // update state
            let mut account_comp_mut = get_dep_component_mut!(ref self, Account);
            account_comp_mut._update_state();

            // validate new class hash is not zero
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);

            // upgrade account
            starknet::syscalls::replace_class_syscall(new_class_hash).unwrap_syscall();
            self
                .emit(
                    TBAUpgraded {
                        account_address: get_contract_address(), class_hash: new_class_hash
                    }
                );
        }
    }
}
