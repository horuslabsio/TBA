// *************************************************************************
//                              LOCKABLE COMPONENT TEST
// *************************************************************************
use starknet::{ContractAddress, account::Call, get_block_timestamp};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_transaction_hash,
    start_cheat_nonce, spy_events, EventSpyAssertionsTrait, ContractClassTrait, ContractClass
};
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

use token_bound_accounts::interfaces::IAccount::{
    IAccountDispatcher, IAccountDispatcherTrait, IAccountSafeDispatcher, IAccountSafeDispatcherTrait
};
use token_bound_accounts::interfaces::ILockable::{ILockableDispatcher, ILockableDispatcherTrait};

use token_bound_accounts::interfaces::IExecutable::{
    IExecutableDispatcher, IExecutableDispatcherTrait
};
use token_bound_accounts::components::presets::account_preset::AccountPreset;
use token_bound_accounts::components::account::account::AccountComponent;
use token_bound_accounts::components::lockable::lockable::LockableComponent;

use token_bound_accounts::test_helper::{
    hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, HelloStarknet},
    erc721_helper::{IERC721Dispatcher, IERC721DispatcherTrait, ERC721},
    simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount}
};


const ACCOUNT: felt252 = 1234;
const ACCOUNT2: felt252 = 5729;
const SALT: felt252 = 123;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
}

fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: 883045738439352841478194533192765345509759306772397516907181243450667673002,
        transaction_hash: 2717105892474786771566982177444710571376803476229898722748888396642649184538,
        r: 3068558690657879390136740086327753007413919701043650133111397282816679110801,
        s: 3355728545224320878895493649495491771252432631648740019139167265522817576501
    }
}

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

    // deploy account contract
    let account_contract = declare("AccountPreset").unwrap();
    let mut acct_constructor_calldata = array![erc721_contract_address.try_into().unwrap(), 1, 0];
    let (account_contract_address, _) = account_contract
        .deploy(@acct_constructor_calldata)
        .unwrap();

    (account_contract_address, erc721_contract_address)
}


#[test]
fn test_lockable_owner() {
    let (contract_address, erc721_contract_address) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let owner = acct_dispatcher.owner();
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    start_cheat_caller_address(contract_address, token_owner);

    assert(owner == token_owner, 'invalid owner');
    stop_cheat_caller_address(contract_address);
}
#[test]
fn test_lockable() {
    let (contract_address, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };

    let owner = acct_dispatcher.owner();

    start_cheat_caller_address(contract_address, owner);

    let lockable_dispatcher = ILockableDispatcher { contract_address };

    lockable_dispatcher.lock(40);
    let check_lock = lockable_dispatcher.is_lock();

    assert(check_lock == true, 'Account Not Lock');
    stop_cheat_caller_address(contract_address);
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

