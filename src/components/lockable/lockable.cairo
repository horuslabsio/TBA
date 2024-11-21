#[starknet::component]
pub mod LockableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    use token_bound_accounts::components::account::account::AccountComponent;
    use token_bound_accounts::components::account::account::AccountComponent::AccountPrivateImpl;
    use openzeppelin::introspection::src5::SRC5Component;

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
        pub const EXCEEDS_MAX_LOCK_TIME: felt252 = 'Account: Lock time > 1 year';
        pub const INVALID_LOCK_TIME: felt252 = 'Account: Lock time set in past';
        pub const LOCKED_ACCOUNT: felt252 = 'Account: Locked';
    }

    // *************************************************************************
    //                              CONSTANTS
    // *************************************************************************
    pub const YEAR_TO_SECONDS: u64 = 31536000;

    // *************************************************************************
    //                              PRIVATE FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    pub impl LockablePrivateImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Account: AccountComponent::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>
    > of LockablePrivateTrait<TContractState> {
        // @notice locks an account
        // @param lock_until time at which this account will no longer be locked
        fn _lock(ref self: ComponentState<TContractState>, lock_until: u64) {
            let current_timestamp = get_block_timestamp();
            // check that lock_until is not set in the past and is not greater than 1 year
            assert(
                lock_until <= current_timestamp + YEAR_TO_SECONDS, Errors::EXCEEDS_MAX_LOCK_TIME
            );
            assert(lock_until > current_timestamp, Errors::INVALID_LOCK_TIME);

            let (lock_status, _) = self._is_locked();
            assert(lock_status != true, Errors::LOCKED_ACCOUNT);

            // update account state
            let mut account_comp_mut = get_dep_component_mut!(ref self, Account);
            account_comp_mut._update_state();

            self.lock_until.write(lock_until);
            self
                .emit(
                    AccountLocked {
                        account: get_caller_address(),
                        locked_at: current_timestamp,
                        lock_until: lock_until
                    }
                );
        }

        // @notice returns the lock status of an account
        fn _is_locked(self: @ComponentState<TContractState>) -> (bool, u64) {
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
