// lockable component
// *************************************************************************
//                              LOCKABLE COMPONENT
// *************************************************************************
#[starknet::component]
pub mod LockableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::interfaces::IAccount::{IAccount, IAccountDispatcherTrait};
    use token_bound_accounts::components::account::account::AccountComponent::InternalImpl;
    use token_bound_accounts::interfaces::ILockable::{
        ILockable, ILockableDispatcher, ILockableDispatcherTrait
    };

    #[storage]
    pub struct Storage {
        lock_until: u64
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AccountLocked: AccountLocked
    }

    /// @notice Emitted when the account is locked
    /// @param account tokenbound account who's lock function was triggered
    /// @param locked_at timestamp at which the lock function was triggered
    /// @param duration time duration for which the account remains locked
    #[derive(Drop, starknet::Event)]
    pub struct AccountLocked {
        #[key]
        pub account: ContractAddress,
        pub locked_at: u64,
        pub lock_until: u64,
    }


    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    pub mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        pub const NOT_OWNER: felt252 = 'Account: Not Account Owner';
        pub const EXCEEDS_MAX_LOCK_TIME: felt252 = 'Lock time exceeded';
        pub const LOCKED_ACCOUNT: felt252 = 'Account Locked';
    }


    // storage that store the token_id and the lock_util perioed

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(LockableImpl)]
    pub impl Lockable<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>
    > of ILockable<ComponentState<TContractState>> {
        fn lock(ref self: ComponentState<TContractState>, lock_until: u64) {
            let current_timestamp = get_block_timestamp();

            let account_comp = get_dep_component!(@self, Account);

            let is_valid = account_comp._is_valid_signer(get_caller_address());
            assert(is_valid, Errors::UNAUTHORIZED);

            assert(lock_until <= current_timestamp + 356, Errors::EXCEEDS_MAX_LOCK_TIME);

            let lock_status = self.is_lock();

            assert(lock_status != true, Errors::LOCKED_ACCOUNT);

            // update account state
            let mut account_comp_mut = get_dep_component_mut!(ref self, Account);
            account_comp_mut._update_state();

            // set the lock_util which set the period the account is lock
            self.lock_until.write(lock_until);
            // emit event
            self
                .emit(
                    AccountLocked {
                        account: get_caller_address(),
                        locked_at: get_block_timestamp(),
                        lock_until: lock_until
                    }
                );
        }

        fn is_lock(self: @ComponentState<TContractState>) -> bool {
            self.lock_until.read() > get_block_timestamp()
        }
    }
}

