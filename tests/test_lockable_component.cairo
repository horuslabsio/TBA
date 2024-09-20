// *************************************************************************
//                              LOCKABLE COMPONENT TEST
// *************************************************************************
use starknet::{ContractAddress, account::Call, get_block_timestamp};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_transaction_hash,
    start_cheat_nonce, spy_events, EventSpyAssertionsTrait, ContractClassTrait, ContractClass,
    start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

use token_bound_accounts::interfaces::IRegistry::{IRegistryDispatcherTrait, IRegistryDispatcher};
use token_bound_accounts::interfaces::IAccount::{IAccountDispatcher, IAccountDispatcherTrait};
use token_bound_accounts::interfaces::ILockable::{ILockableDispatcher, ILockableDispatcherTrait};
use token_bound_accounts::interfaces::IExecutable::{
    IExecutableDispatcher, IExecutableDispatcherTrait
};
use token_bound_accounts::interfaces::IUpgradeable::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait
};
use token_bound_accounts::interfaces::IERC721::{IERC721Dispatcher, IERC721DispatcherTrait};
use token_bound_accounts::components::presets::account_preset::AccountPreset;
use token_bound_accounts::components::lockable::lockable::LockableComponent;

use token_bound_accounts::test_helper::{
    hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, HelloStarknet},
    simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount},
    erc721_helper::ERC721
};

const ACCOUNT2: felt252 = 5729;

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (ContractAddress, ContractAddress) {
    // deploy erc721 helper contract
    let erc721_contract = declare("ERC721").unwrap();
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let (erc721_contract_address, _) = erc721_contract
        .deploy(@erc721_constructor_calldata)
        .unwrap();

    // deploy recipient contract
    let account_contract = declare("SimpleAccount").unwrap();
    let (recipient, _) = account_contract
        .deploy(
            @array![883045738439352841478194533192765345509759306772397516907181243450667673002]
        )
        .unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    dispatcher.mint(recipient, 1.try_into().unwrap());

    // deploy registry contract
    let registry_contract = declare("Registry").unwrap();
    let (registry_contract_address, _) = registry_contract.deploy(@array![]).unwrap();

    // deploy account contract
    let account_contract = declare("AccountPreset").unwrap();
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(),
        1,
        0,
        registry_contract_address.try_into().unwrap(),
        account_contract.class_hash.into(),
        20
    ];
    let (account_contract_address, _) = account_contract
        .deploy(@acct_constructor_calldata)
        .unwrap();

    (account_contract_address, erc721_contract_address)
}

// *************************************************************************
//                              TESTS
// *************************************************************************
#[test]
fn test_lockable() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let owner = acct_dispatcher.owner();

    start_cheat_caller_address(contract_address, owner);

    let lockable_dispatcher = ILockableDispatcher { contract_address };
    let lock_duration = 40_u64;
    lockable_dispatcher.lock(lock_duration);
    let (check_lock, _) = lockable_dispatcher.is_locked();

    assert(check_lock == true, 'Account Not Locked');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_unlock_once_lock_duration_end() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let owner = acct_dispatcher.owner();

    start_cheat_caller_address(contract_address, owner);

    start_cheat_block_timestamp(contract_address, 20_u64);
    let lockable_dispatcher = ILockableDispatcher { contract_address };
    let lock_duration = 40_u64;
    lockable_dispatcher.lock(lock_duration);
    stop_cheat_block_timestamp(contract_address);

    start_cheat_block_timestamp(contract_address, 100_u64);
    let (is_locked, _) = lockable_dispatcher.is_locked();
    assert(is_locked == false, 'Account is still locked');
    stop_cheat_block_timestamp(contract_address);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Account: locked',))]
fn test_execute_should_fail_when_locked() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };
    let safe_dispatcher = IExecutableDispatcher { contract_address };

    let owner = acct_dispatcher.owner();
    let lock_duration = 30_u64;

    let lockable_dispatcher = ILockableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    lockable_dispatcher.lock(lock_duration);

    stop_cheat_caller_address(contract_address);

    // deploy `HelloStarknet` contract for testing
    let test_contract = declare("HelloStarknet").unwrap();
    let (test_address, _) = test_contract.deploy(@array![]).unwrap();

    // craft calldata for call array
    let mut calldata = array![100].span();
    let call = Call {
        to: test_address,
        selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
        calldata: calldata
    };

    start_cheat_caller_address(contract_address, owner);
    safe_dispatcher.execute(array![call]);
}

#[test]
#[should_panic(expected: ('Account: locked',))]
fn test_upgrade_should_fail_when_locked() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };
    let new_class_hash = declare("UpgradedAccount").unwrap().class_hash;

    let owner = acct_dispatcher.owner();
    let lock_duration = 30_u64;

    let lockable_dispatcher = ILockableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    lockable_dispatcher.lock(lock_duration);
    stop_cheat_caller_address(contract_address);

    // call the upgrade function
    let dispatcher = IUpgradeableDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.upgrade(new_class_hash);
}
#[test]
#[should_panic(expected: ('Account: Locked',))]
fn test_locking_should_fail_if_already_locked() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let owner = acct_dispatcher.owner();

    start_cheat_caller_address(contract_address, owner);

    let lock_duration = 40_u64;
    let lockable_dispatcher = ILockableDispatcher { contract_address };
    // first Lock
    lockable_dispatcher.lock(lock_duration);
    // second lock
    lockable_dispatcher.lock(lock_duration);
}

#[test]
#[should_panic(expected: ('Account: Lock time exceeded',))]
fn test_should_fail_for_greater_than_a_year_lock_time() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let owner = acct_dispatcher.owner();
    let lock_duration = 315365000_u64;

    let lockable_dispatcher = ILockableDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    lockable_dispatcher.lock(lock_duration);
}

#[test]
fn test_lockable_emits_event() {
    let (contract_address, _) = __setup__();

    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let owner = acct_dispatcher.owner();

    // spy on emitted events
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);

    // call the lock function
    let lockable_dispatcher = ILockableDispatcher { contract_address: contract_address };

    lockable_dispatcher.lock(40);

    // check events are emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    LockableComponent::Event::AccountLocked(
                        LockableComponent::AccountLocked {
                            account: owner, locked_at: get_block_timestamp(), lock_until: 40
                        }
                    )
                )
            ]
        );
}

