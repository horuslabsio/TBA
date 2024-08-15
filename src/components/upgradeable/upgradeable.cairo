// *************************************************************************
//                              UPGRADEABLE COMPONENT
// *************************************************************************
#[starknet::component]
mod UpgradeableComponent {
    use starknet::{ ClassHash, SyscallResultTrait };
    use core::zeroable::Zeroable;

    use token_bound_accounts::interfaces::IUpgradeable::IUpgradeable;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {}

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    /// @notice Emitted when the contract is upgraded.
    /// @param class_hash implementation hash to be upgraded to
    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    mod Errors {
        const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(AccountUpgradeable)]
    impl Upgradeable<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IUpgradeable<ComponentState<TContractState>> {
        /// @notice replaces the contract's class hash with `new_class_hash`.
        /// @notice whilst implementing this component, ensure to validate the signer/caller by calling `is_valid_signer`.
        /// Emits an `Upgraded` event.
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);
            starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
