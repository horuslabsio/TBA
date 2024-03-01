////////////////////////////////
// Upgradeable Component
////////////////////////////////
#[starknet::component]
mod UpgradeableComponent {
    use starknet::ClassHash;
    use starknet::SyscallResultTrait;
    use token_bound_accounts::interfaces::IUpgradeable;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    /// Emitted when the contract is upgraded.
    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    mod Errors {
        const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// @notice eplaces the contract's class hash with `new_class_hash`.
        /// Emits an `Upgraded` event.
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);
            starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
