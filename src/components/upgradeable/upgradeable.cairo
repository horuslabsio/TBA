// *************************************************************************
//                              UPGRADEABLE COMPONENT
// *************************************************************************
#[starknet::component]
mod UpgradeableComponent {
    use starknet::{ClassHash, SyscallResultTrait};
    use core::num::traits::zero::Zero;

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
    pub mod Errors {
        pub const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
    }

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// @notice replaces the contract's class hash with `new_class_hash`.
        /// Emits an `Upgraded` event.
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            // TODO: validate new signer
            // TODO: update state
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);
            starknet::syscalls::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
