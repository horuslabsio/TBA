// *************************************************************************
//                              REGISTRY TEST
// *************************************************************************
use starknet::ContractAddress;
use snforge_std::{declare, start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait, ContractClassTrait, ContractClass};

use token_bound_accounts::interfaces::IRegistry::{IRegistryDispatcherTrait, IRegistryDispatcher};
use token_bound_accounts::registry::registry::Registry;

use token_bound_accounts::interfaces::IUpgradeable::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait
};

use token_bound_accounts::interfaces::IAccount::{IAccountDispatcher, IAccountDispatcherTrait};
use token_bound_accounts::components::presets::account_preset::AccountPreset;

use token_bound_accounts::test_helper::erc721_helper::{
    IERC721Dispatcher, IERC721DispatcherTrait, ERC721
};

const ACCOUNT: felt252 = 1234;

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (ContractAddress, ContractAddress) {
    // deploy erc721 helper contract
    let erc721_contract = declare("ERC721").unwrap();
    let (erc721_contract_address, _) = erc721_contract.deploy(
        @array!['tokenbound', 'TBA']
    ).unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let recipient: ContractAddress = ACCOUNT.try_into().unwrap();
    dispatcher.mint(recipient, 1.try_into().unwrap());

    // deploy registry contract
    let registry_contract = declare("Registry").unwrap();
    let (registry_contract_address, _) = registry_contract.deploy(@array![]).unwrap();

    (registry_contract_address, erc721_contract_address)
}

// *************************************************************************
//                              TESTS
// *************************************************************************
#[test]
fn test_create_account() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher = IRegistryDispatcher { contract_address: registry_contract_address };

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    start_cheat_caller_address(registry_contract_address, token_owner);

    // create account
    let acct_class_hash = declare("AccountPreset").unwrap().class_hash;
    let account_address = registry_dispatcher
        .create_account(
            acct_class_hash.into(),
            erc721_contract_address,
            1.try_into().unwrap(),
            245828,
            'SN_SEPOLIA'
        );
    stop_cheat_caller_address(registry_contract_address);

    // confirm account deployment by checking the account owner
    let acct_dispatcher = IAccountDispatcher { contract_address: account_address };
    let TBA_owner = acct_dispatcher.owner();
    assert(TBA_owner == token_owner, 'acct deployed wrongly');
}

#[test]
#[should_panic(expected: ('Registry: caller is not owner',))]
fn test_create_account_should_fail_if_not_nft_owner() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher = IRegistryDispatcher { contract_address: registry_contract_address };

    // create account
    let acct_class_hash = declare("AccountPreset").unwrap().class_hash;
    registry_dispatcher.create_account(
        acct_class_hash.into(),
        erc721_contract_address,
        1.try_into().unwrap(),
        245828,
        'SN_SEPOLIA'
    );
}

#[test]
fn test_create_account_emits_event() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher = IRegistryDispatcher { contract_address: registry_contract_address };

    // spy on emitted events
    let mut spy = spy_events();

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    start_cheat_caller_address(registry_contract_address, token_owner);

    // create account
    let acct_class_hash = declare("AccountPreset").unwrap().class_hash;
    let account_address = registry_dispatcher.create_account(
        acct_class_hash.into(),
        erc721_contract_address,
        1.try_into().unwrap(),
        245828,
        'SN_SEPOLIA'
    );
    stop_cheat_caller_address(registry_contract_address);

    // check events are emitted
    spy.assert_emitted(@array![
        (
            registry_contract_address,
            Registry::Event::AccountCreated(
                Registry::AccountCreated {
                    account_address,
                    token_contract: erc721_contract_address,
                    token_id: 1.try_into().unwrap()
                }
            )
        )
    ]);
}

#[test]
fn test_get_account() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher = IRegistryDispatcher { contract_address: registry_contract_address };

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    start_cheat_caller_address(registry_contract_address, token_owner);

    // deploy account
    let acct_class_hash = declare("AccountPreset").unwrap().class_hash;
    let account_address = registry_dispatcher
        .create_account(
            acct_class_hash.into(),
            erc721_contract_address,
            1.try_into().unwrap(),
            252520,
            'SN_SEPOLIA'
        );
    stop_cheat_caller_address(registry_contract_address);

    // get account
    let account = registry_dispatcher
        .get_account(
            acct_class_hash.into(),
            erc721_contract_address,
            1.try_into().unwrap(),
            252520,
            'SN_SEPOLIA'
        );

    // compare both addresses
    assert(account == account_address, 'get_account computes wrongly');
}
