// *************************************************************************
//                              BASE ACCOUNT PRESET
// *************************************************************************
#[starknet::contract]
pub mod AccountPreset {
    use starknet::{ContractAddress, get_caller_address, ClassHash, account::Call};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::upgradeable::upgradeable::UpgradeableComponent;
    use token_bound_accounts::components::lockable::lockable::LockableComponent;
    use token_bound_accounts::interfaces::{
        IUpgradeable::IUpgradeable, IExecutable::IExecutable, ILockable::ILockable
    };

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: LockableComponent, storage: lockable, event: LockableEvent);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;

    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::Private<ContractState>;
    impl LockableImpl = LockableComponent::LockableImpl<ContractState>;

    // *************************************************************************
    //                             STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        lockable: LockableComponent::Storage,
    }

    // *************************************************************************
    //                              EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        LockableEvent: LockableComponent::Event
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress, token_id: u256) {
        self.account.initializer(token_contract, token_id);
    }

    // *************************************************************************
    //                              EXECUTABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Executable of IExecutable<ContractState> {
        fn execute(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            // cannot make this call when the account is lock
            let (is_locked, _) = self.lockable.is_locked();
            assert(is_locked != true, 'Account: locked');
            self.account._execute(calls)
        }
    }

    // *************************************************************************
    //                              UPGRADEABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Upgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // cannot make this call when the account is lock
            let (is_locked, _) = self.lockable.is_locked();
            assert(is_locked != true, 'Account: locked');
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    // *************************************************************************
    //                              LOCKABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Lockable of ILockable<ContractState> {
        fn lock(ref self: ContractState, lock_until: u64) {
            self.lockable.lock(lock_until);
        }
        fn is_locked(self: @ContractState) -> (bool, u64) {
            self.lockable.is_locked()
        }
    }
}
