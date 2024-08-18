// *************************************************************************
//                              UPGRADEABLE COMPONENT
// *************************************************************************
#[starknet::component]
pub mod UpgradeableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::{ClassHash, SyscallResultTrait, get_caller_address};
    use core::num::traits::zero::Zero;
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::account::account::AccountComponent::InternalImpl;

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
        Upgraded: Upgraded
    }

    /// @notice Emitted when the contract is upgraded.
    /// @param class_hash implementation hash to be upgraded to
    #[derive(Drop, starknet::Event)]
    pub struct Upgraded {
        pub class_hash: ClassHash
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
    }

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl Private<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>
    > of PrivateTrait<TContractState> {
        /// @notice replaces the contract's class hash with `new_class_hash`.
        /// Emits an `Upgraded` event.
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            // validate new signer
            let account_comp = get_dep_component!(@self, Account);
            let is_valid = account_comp._is_valid_signer(get_caller_address());
            assert(is_valid, Errors::UNAUTHORIZED);

            // update state
            let mut account_comp_mut = get_dep_component_mut!(ref self, Account);
            account_comp_mut._update_state();

            // validate new class hash is not zero
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);

            // upgrade account
            starknet::syscalls::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
