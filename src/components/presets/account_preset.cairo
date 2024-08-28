// *************************************************************************
//                              BASE ACCOUNT PRESET
// *************************************************************************
#[starknet::contract]
pub mod AccountPreset {
    use starknet::{ContractAddress, get_caller_address, ClassHash, account::Call};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::upgradeable::upgradeable::UpgradeableComponent;
    use token_bound_accounts::components::lockable::lockable::LockableComponent;
    use token_bound_accounts::components::signatory::signatory::SignatoryComponent;
    use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent;
    use token_bound_accounts::interfaces::{
        IUpgradeable::IUpgradeable, IExecutable::IExecutable, ILockable::ILockable,
        ISignatory::ISignatory, IPermissionable::IPermissionable
    };

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: LockableComponent, storage: lockable, event: LockableEvent);
    component!(path: SignatoryComponent, storage: signatory, event: SignatoryEvent);
    component!(path: PermissionableComponent, storage: permissionable, event: PermissionableEvent);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;

    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::Private<ContractState>;
    impl LockableImpl = LockableComponent::LockableImpl<ContractState>;
    impl SignerImpl = SignatoryComponent::Private<ContractState>;

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
        #[substorage(v0)]
        signatory: SignatoryComponent::Storage,
        #[substorage(v0)]
        permissionable: PermissionableComponent::Storage,
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
        LockableEvent: LockableComponent::Event,
        #[flat]
        SignatoryEvent: SignatoryComponent::Event,
        #[flat]
        PermissionableEvent: PermissionableComponent::Event
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, token_contract: ContractAddress, token_id: u256) {
        self.account.initializer(token_contract, token_id);
    }

    // *************************************************************************
    //                              SIGNATORY IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Signatory of ISignatory<ContractState> {
        fn is_valid_signer(self: @ContractState, signer: ContractAddress) -> bool {
            self.signatory._permissioned_signer_validation(signer)
        }
    }

    // *************************************************************************
    //                              EXECUTABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Executable of IExecutable<ContractState> {
        fn execute(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), 'Account: unauthorized');

            // cannot make this call when the account is lock
            let (is_locked, _) = self.lockable.is_locked();
            assert(is_locked != true, 'Account: locked');

            // execute calls
            self.account._execute(calls)
        }
    }

    // *************************************************************************
    //                              UPGRADEABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Upgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), 'Account: unauthorized');

            // cannot make this call when the account is lock
            let (is_locked, _) = self.lockable.is_locked();
            assert(is_locked != true, 'Account: locked');

            // upgrade account
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    // *************************************************************************
    //                              LOCKABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Lockable of ILockable<ContractState> {
        fn lock(ref self: ContractState, lock_until: u64) {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), 'Account: unauthorized');

            // lock account
            self.lockable.lock(lock_until);
        }

        fn is_locked(self: @ContractState) -> (bool, u64) {
            self.lockable.is_locked()
        }
    }

    // *************************************************************************
    //                              PERMISSIONABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Permissionable of IPermissionable<ContractState> {
        fn set_permission(
            ref self: ContractState,
            permissioned_addresses: Array<ContractAddress>,
            permissions: Array<bool>
        ) {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), 'Account: unauthorized');

            // set permissions
            self.permissionable.set_permission(permissioned_addresses, permissions)
        }

        fn has_permission(
            self: @ContractState, owner: ContractAddress, permissioned_address: ContractAddress
        ) -> bool {
            self.permissionable.has_permission(owner, permissioned_address)
        }
    }
}
