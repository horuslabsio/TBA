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
    use token_bound_accounts::components::account::account::AccountComponent::AccountPrivateImpl;
    use token_bound_accounts::interfaces::ILockable::{
        ILockable, ILockableDispatcher, ILockableDispatcherTrait
    };

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    pub struct Storage {
        lock_until: u64
    }

    // *************************************************************************
    //                              EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AccountLocked: AccountLocked
    }

    /// @notice Emitted when the account is locked
    /// @param account tokenbound account who's lock function was triggered
    /// @param locked_at timestamp at which the lock function was triggered
    /// @param lock_until time duration for which the account remains locked in second
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
        pub const EXCEEDS_MAX_LOCK_TIME: felt252 = 'Account: Lock time exceeded';
        pub const LOCKED_ACCOUNT: felt252 = 'Account: Locked';
    }

    // *************************************************************************
    //                              CONSTANTS
    // *************************************************************************
    pub const YEAR_DAYS_SECONDS: u64 = 31536000;

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl LockablePrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>,
    > of LockablePrivateTrait<TContractState> {
        // @notice locks an account
        // @param lock_until duration for which account should be locked
        fn lock(ref self: ComponentState<TContractState>, lock_until: u64) {
            let current_timestamp = get_block_timestamp();
            assert(
                lock_until <= current_timestamp + YEAR_DAYS_SECONDS, Errors::EXCEEDS_MAX_LOCK_TIME
            );

            let (lock_status, _) = self.is_locked();
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

        // @notice returns the lock status of an account
        fn is_locked(self: @ComponentState<TContractState>) -> (bool, u64) {
            let unlock_timestamp = self.lock_until.read();
            let current_time = get_block_timestamp();
            if (current_time < unlock_timestamp) {
                let time_until_unlocks = unlock_timestamp - current_time;
                return (true, time_until_unlocks);
            } else {
                return (false, 0_u64);
            }
        }
    }
}
