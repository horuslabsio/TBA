// lockable component
// *************************************************************************
//                              LOCKABLE COMPONENT
// *************************************************************************
#[starknet::component]
mod LockableComponent {
    // *************************************************************************
    //                              IMPORTS
    // *************************************************************************
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use token_bound_accounts::account::AccountComponent;
    use token_bound_accounts::interfaces::IAccount::{
        IAccount, IAccountDispatcherTrait, ILockableDispatcher
    };

    component!(path: AccountComponent, storage: account, event: AccountEvent);

    // Account
    #[abi(embed_v0)]
    impl AccountImpl = AccountComponent::AccountImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        lock_util: u64,
        #[substorage(v0)]
        account: AccountComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        LockUpdated: LockUpdated
    }

    /// @notice Emitted when the account is locked
    /// @param account tokenbound account who's lock function was triggered
    /// @param locked_at timestamp at which the lock function was triggered
    /// @param duration time duration for which the account remains locked
    #[derive(Drop, starknet::Event)]
    struct AccountLocked {
        #[key]
        account: ContractAddress,
        locked_at: u64,
        lock_util: u64,
    }


    // *************************************************************************
    //                              ERRORS
    // *************************************************************************
    mod Errors {
        const UNAUTHORIZED: felt252 = 'Account: unauthorized';
        const NOT_OWNER: felt252 = 'Not Account Owner';
        const EXCEEDS_MAX_LOCK_TIME: felt252 = 'Lock time exceeded';
        const LOCKED_ACCOUNT: felt252 = 'Account Locked';
    }


    // storage that store the token_id and the lock_util perioed

    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************
    #[embeddable_as(LockableImpl)]
    impl Lockable<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of ILockable<ComponentState<TContractState>> {
        fn lock(ref self: @ComponentState<TContractState>, lock_until: u64) {
            let current_timestamp = get_block_timestamp();

            // get the token 
            let (token_contract, token_id, chain_id) = self.account.token();

            // get the token owner
            let owner = self.account.owner();

            assert(owner.is_non_zero(), Errors::UNAUTHORIZED);
            assert(get_caller_address != owner, Errors::NOT_OWNER);

            assert(lock_until <= current_timestamp + 356, EXCEEDS_MAX_LOCK_TIME);

            // _beforeLock may be call before upating the lock period
            let ock_status = self._is_locked();
            assert(!lock_status, Errors::LOCKED_ACCOUNT);
            // set the lock_util which set the period the account is lock 
            self.lock_util.write(lock_until);

            // emit event
            self
                .emit(
                    AccountLocked {
                        account: get_contract_address(), locked_at: current_timestamp, lock_util
                    }
                );
        }

        fn is_lock(self: @TContractState) -> bool {
            self.lock_until.read() > get_block_timestamp()
        }
    }
}

