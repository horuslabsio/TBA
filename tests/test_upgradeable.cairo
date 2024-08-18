// *************************************************************************
//                              UPGRADEABLE COMPONENT TEST
// *************************************************************************
use starknet::{ContractAddress, account::Call};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, spy_events,
    EventSpyAssertionsTrait, ContractClassTrait, ContractClass
};
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

use token_bound_accounts::interfaces::IAccount::{
    IAccountDispatcher, IAccountDispatcherTrait, IAccountSafeDispatcher, IAccountSafeDispatcherTrait
};
use token_bound_accounts::interfaces::IUpgradeable::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait
};
use token_bound_accounts::components::presets::account_preset::AccountPreset;
use token_bound_accounts::components::account::account::AccountComponent;

use token_bound_accounts::test_helper::{
    erc721_helper::{IERC721Dispatcher, IERC721DispatcherTrait, ERC721},
    simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount},
    account_upgrade::{IUpgradedAccountDispatcher, IUpgradedAccountDispatcherTrait, UpgradedAccount}
};

const ACCOUNT: felt252 = 1234;
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

    // deploy account contract
    let account_contract = declare("AccountPreset").unwrap();
    let mut acct_constructor_calldata = array![erc721_contract_address.try_into().unwrap(), 1, 0];
    let (account_contract_address, _) = account_contract
        .deploy(@acct_constructor_calldata)
        .unwrap();

    (account_contract_address, erc721_contract_address)
}

// *************************************************************************
//                              TESTS
// *************************************************************************
#[test]
fn test_upgrade() {
    let (contract_address, erc721_contract_address) = __setup__();

    let new_class_hash = declare("UpgradedAccount").unwrap().class_hash;

    // get token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    // call the upgrade function
    let dispatcher = IUpgradeableDispatcher { contract_address };
    start_cheat_caller_address(contract_address, token_owner);
    dispatcher.upgrade(new_class_hash);

    // try to call the version function
    let upgraded_dispatcher = IUpgradedAccountDispatcher { contract_address };
    let version = upgraded_dispatcher.version();
    assert(version == 1_u8, 'upgrade unsuccessful');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_upgrade_with_unauthorized() {
    let (contract_address, _) = __setup__();

    let new_class_hash = declare("UpgradedAccount").unwrap().class_hash;

    // call upgrade function with an unauthorized address
    start_cheat_caller_address(contract_address, ACCOUNT2.try_into().unwrap());
    let safe_upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
    safe_upgrade_dispatcher.upgrade(new_class_hash);
}
