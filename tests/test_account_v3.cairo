use starknet::{ContractAddress, account::Call};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_account_contract_address, stop_cheat_account_contract_address,
    start_cheat_transaction_hash, start_cheat_nonce, spy_events, EventSpyAssertionsTrait,
    ContractClassTrait, ContractClass, start_cheat_chain_id, stop_cheat_chain_id,
    start_cheat_chain_id_global, stop_cheat_chain_id_global
};
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

use token_bound_accounts::interfaces::IRegistry::{IRegistryDispatcherTrait, IRegistryDispatcher};
use token_bound_accounts::interfaces::IERC721::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721SafeDispatcher, IERC721SafeDispatcherTrait
};
use token_bound_accounts::interfaces::IAccount::{IAccountDispatcher, IAccountDispatcherTrait};
use token_bound_accounts::interfaces::IPermissionable::{
    IPermissionableDispatcher, IPermissionableDispatcherTrait
};
use token_bound_accounts::interfaces::ISignatory::{ISignatoryDispatcher, ISignatoryDispatcherTrait};
use token_bound_accounts::interfaces::IAccountV3::{IAccountV3Dispatcher, IAccountV3DispatcherTrait};
use token_bound_accounts::test_helper::{
    hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, HelloStarknet},
    simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount},
    erc721_helper::ERC721
};


const ACCOUNT: felt252 = 1234;
const ACCOUNT1: felt252 = 5739;
const ACCOUNT2: felt252 = 5729;
const SALT: felt252 = 123;


// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress, felt252) {
    // deploy erc721 helper contract
    let erc721_contract = declare("ERC721").unwrap();
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let (erc721_contract_address, _) = erc721_contract
        .deploy(@erc721_constructor_calldata)
        .unwrap();

    // deploy recipient contract
    let recipient_contract_class = declare("SimpleAccount").unwrap();
    let (recipient, _) = recipient_contract_class
        .deploy(
            @array![883045738439352841478194533192765345509759306772397516907181243450667673002]
        )
        .unwrap();

    // mint new tokens
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    dispatcher.mint(recipient, 1.try_into().unwrap());
    dispatcher.mint(recipient, 2.try_into().unwrap());

    // deploy registry contract
    let registry_contract = declare("Registry").unwrap();
    let (registry_contract_address, _) = registry_contract.deploy(@array![]).unwrap();

    // deploy account V3 contract
    let account_v3_contract_class = declare("AccountV3").unwrap();
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(),
        1,
        0,
        registry_contract_address.try_into().unwrap(),
        account_v3_contract_class.class_hash.into(),
        20
    ];
    let (account_v3_contract_address, _) = account_v3_contract_class
        .deploy(@acct_constructor_calldata)
        .unwrap();

    (
        erc721_contract_address,
        recipient,
        account_v3_contract_address,
        registry_contract_address,
        account_v3_contract_class.class_hash.into()
    )
}

#[test]
fn test_on_erc721_received_with_safe_transfer() {
    let (erc721_contract_address, recipient, account_v3_contract_address, _, _) = __setup__();
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };

    start_cheat_caller_address(erc721_contract_address, recipient);
    start_cheat_chain_id_global('SN_SEPOLIA');

    // call safe transfer
    erc721_dispatcher
        .safe_transfer_from(recipient, account_v3_contract_address, 2, array![].span());

    // check safe transfer was successful
    let owner = erc721_dispatcher.owner_of(2);
    assert(owner == account_v3_contract_address, 'safe transfer failed!');
}

#[test]
#[feature("safe dispatcher")]
fn test_safe_transfer_fails_if_owner_cycle_detected() {
    let (erc721_contract_address, recipient, account_v3_contract_address, _, _) = __setup__();
    let erc721_dispatcher = IERC721SafeDispatcher { contract_address: erc721_contract_address };

    start_cheat_caller_address(erc721_contract_address, recipient);
    start_cheat_chain_id_global('SN_SEPOLIA');

    // call safe transfer with token ID that owns the TBA
    match erc721_dispatcher
        .safe_transfer_from(recipient, account_v3_contract_address, 1, array![].span()) {
        Result::Ok(_) => panic!("Expected safe transfer to panic!"),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Account: ownership cycle!', *panic_data.at(0))
        }
    };
}

#[test]
fn test_context() {
    let (_, _, account_v3_contract_address, registry, implementation) = __setup__();
    let dispatcher = IAccountV3Dispatcher { contract_address: account_v3_contract_address };

    // get context and check it's correct
    let (_registry, _implementation, _salt) = dispatcher.context();
    assert(_registry == registry, 'invalid registry');
    assert(_implementation == implementation, 'invalid implementation');
    assert(_salt == 20, 'invalid salt');
}


#[test]
fn test_owner_and_permissioned_accounts_is_valid_signer() {
    let (erc721_contract_address, _, account_v3_contract_address, _, _,) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: account_v3_contract_address };

    let signatory_dispatcher = ISignatoryDispatcher {
        contract_address: account_v3_contract_address
    };

    let owner = acct_dispatcher.owner();

    // get token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    let mut permission_addresses = ArrayTrait::new();
    permission_addresses.append(ACCOUNT2.try_into().unwrap());
    permission_addresses.append(token_owner);

    let mut permissions = ArrayTrait::new();
    permissions.append(true);
    permissions.append(true);

    start_cheat_caller_address(account_v3_contract_address, owner);

    let permissionable_dispatcher = IPermissionableDispatcher {
        contract_address: account_v3_contract_address
    };
    permissionable_dispatcher.set_permission(permission_addresses, permissions);

    let has_permission2 = permissionable_dispatcher.has_permission(owner, token_owner);
    assert(has_permission2 == true, 'Account: permitted');

    stop_cheat_caller_address(account_v3_contract_address);

    // check owner is a valid signer
    start_cheat_caller_address(account_v3_contract_address, owner);
    let is_valid_signer = signatory_dispatcher.is_valid_signer(owner);
    assert(is_valid_signer == true, 'should be a valid signer');

    stop_cheat_caller_address(account_v3_contract_address);

    // check permission address is a valid signer
    start_cheat_caller_address(account_v3_contract_address, token_owner);
    let is_valid_signer = signatory_dispatcher.is_valid_signer(token_owner);
    assert(is_valid_signer == true, 'should be a valid signer');

    stop_cheat_caller_address(account_v3_contract_address);
}

