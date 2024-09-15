// *************************************************************************
//                              ACCOUNT V3
// *************************************************************************

#[starknet::contract]
pub mod AccountV3 {
    // *************************************************************************
    //                             IMPORTS
    // *************************************************************************
    use starknet::{ContractAddress, get_caller_address, get_tx_info, ClassHash, account::Call};
    use openzeppelin::introspection::src5::SRC5Component;

    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::upgradeable::upgradeable::UpgradeableComponent;
    use token_bound_accounts::components::lockable::lockable::LockableComponent;
    use token_bound_accounts::components::signatory::signatory::SignatoryComponent;
    use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent;
    use token_bound_accounts::interfaces::{
        IUpgradeable::IUpgradeable, IExecutable::IExecutable, ILockable::ILockable,
        ISignatory::ISignatory, IPermissionable::IPermissionable, IAccountV3::IAccountV3
    };

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: LockableComponent, storage: lockable, event: LockableEvent);
    component!(path: SignatoryComponent, storage: signatory, event: SignatoryEvent);
    component!(path: PermissionableComponent, storage: permissionable, event: PermissionableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;

    impl AccountInternalImpl = AccountComponent::AccountPrivateImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::UpgradeablePrivateImpl<ContractState>;
    impl LockableInternalImpl = LockableComponent::LockablePrivateImpl<ContractState>;
    impl SignerInternalImpl = SignatoryComponent::SignatoryPrivateImpl<ContractState>;
    impl PermissionableInternalImpl =
        PermissionableComponent::PermissionablePrivateImpl<ContractState>;

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
        #[substorage(v0)]
        src5: SRC5Component::Storage
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
        PermissionableEvent: PermissionableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        pub const ACCOUNT_LOCKED: felt252 = 'Account: locked';
    }

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_contract: ContractAddress,
        token_id: u256,
        registry: ContractAddress,
        implementation_hash: felt252,
        salt: felt252
    ) {
        self.account.initializer(token_contract, token_id, registry, implementation_hash, salt);
    }

    // *************************************************************************
    //                              ACCOUNT V3 IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl AccountV3 of IAccountV3<ContractState> {
        /// @notice called whenever an ERC-721 token is received.
        /// @notice revferts if token being received is the token account is bound to.
        /// @param operator who sent the NFT (typically the caller)
        /// @param from previous owner (caller who called `safe_transfer_from`)
        /// @param token_id the NFT token ID being transferred
        /// @param data additional data
        fn on_erc721_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            let (_token_contract, _token_id, _chain_id) = self.account.token();
            let tx_info = get_tx_info().unbox();

            if (get_caller_address() == _token_contract
                && token_id == _token_id
                && tx_info.chain_id == _chain_id) {
                panic!("Account: ownership cycle!");
            }

            return 0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;
        }

        /// @notice retrieves deployment details of an account
        fn get_context(self: @ContractState) -> (ContractAddress, felt252, felt252) {
            self.account._context()
        }
    }

    // *************************************************************************
    //                              SIGNATORY IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Signatory of ISignatory<ContractState> {
        /// @notice implements signer validation where NFT owner, root owner, and
        /// permissioned addresses are valid signers.
        /// @param signer the address to be validated
        fn is_valid_signer(self: @ContractState, signer: ContractAddress) -> bool {
            self.signatory._permissioned_signer_validation(signer)
        }

        /// @notice used for signature validation
        /// @param hash The message hash
        /// @param signature The signature to be validated
        fn is_valid_signature(
            self: @ContractState, hash: felt252, signature: Span<felt252>
        ) -> felt252 {
            self.signatory._is_valid_signature(hash, signature)
        }
    }

    // *************************************************************************
    //                              EXECUTABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Executable of IExecutable<ContractState> {
        // @notice executes a transaction
        // @notice this should be called within an `execute` method in implementation contracts
        // @param calls an array of transactions to be executed
        fn execute(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), Errors::UNAUTHORIZED);

            // cannot make this call when the account is lock
            let (is_locked, _) = self.lockable.is_locked();
            assert(is_locked != true, Errors::ACCOUNT_LOCKED);

            // execute calls
            self.account._execute(calls)
        }
    }

    // *************************************************************************
    //                              UPGRADEABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Upgradeable of IUpgradeable<ContractState> {
        /// @notice replaces the contract's class hash with `new_class_hash`.
        /// Emits an `Upgraded` event.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), Errors::UNAUTHORIZED);

            // cannot make this call when the account is lock
            let (is_locked, _) = self.lockable.is_locked();
            assert(is_locked != true, Errors::ACCOUNT_LOCKED);

            // upgrade account
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    // *************************************************************************
    //                              LOCKABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Lockable of ILockable<ContractState> {
        // @notice locks an account
        // @param lock_until duration for which account should be locked
        fn lock(ref self: ContractState, lock_until: u64) {
            // validate signer
            let caller = get_caller_address();
            assert(self.is_valid_signer(caller), Errors::UNAUTHORIZED);

            // lock account
            self.lockable.lock(lock_until);
        }

        // @notice returns the lock status of an account
        fn is_locked(self: @ContractState) -> (bool, u64) {
            self.lockable.is_locked()
        }
    }

    // *************************************************************************
    //                              PERMISSIONABLE IMPL
    // *************************************************************************
    #[abi(embed_v0)]
    impl Permissionable of IPermissionable<ContractState> {
        // @notice sets permission for an account
        // @permissioned_addresses array of addresses who's permission is to be updated
        // @param permssions permission value <true, false>
        fn set_permission(
            ref self: ContractState,
            permissioned_addresses: Array<ContractAddress>,
            permissions: Array<bool>
        ) {
            // validate signer is owner
            let caller = get_caller_address();
            assert(self.signatory._base_signer_validation(caller), Errors::UNAUTHORIZED);

            // set permissions
            self.permissionable.set_permission(permissioned_addresses, permissions)
        }

        // @notice returns if a user has permission or not
        // @param owner tokenbound account owner
        // @param permissioned_address address to check permission for
        fn has_permission(
            self: @ContractState, owner: ContractAddress, permissioned_address: ContractAddress
        ) -> bool {
            self.permissionable.has_permission(owner, permissioned_address)
        }
    }
}
