// test for function
// on_erc721_received

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
use token_bound_accounts::interfaces::IAccount::{
    IAccountDispatcher, IAccountDispatcherTrait, IAccountSafeDispatcher,
    IAccountSafeDispatcherTrait,
};
use token_bound_accounts::interfaces::IAccountV3::{
    IAccountV3Dispatcher, IAccountV3DispatcherTrait, IAccountV3SafeDispatcher,
    IAccountV3SafeDispatcherTrait,
};
// use token_bound_accounts::interfaces::IAccountV3::{
//     IAccountV3Dispatcher, IAccountV3DispatcherTrait, IAccountV3SafeDispatcher,
//     IAccountV3SafeDispatcherTrait
// };
use token_bound_accounts::interfaces::IExecutable::{
    IExecutableDispatcher, IExecutableDispatcherTrait
};
use token_bound_accounts::components::presets::account_preset::AccountPreset;
use token_bound_accounts::components::account::account::AccountComponent;
use token_bound_accounts::registry::registry::Registry;

use token_bound_accounts::test_helper::{
    hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, HelloStarknet},
    erc721_helper::{IERC721Dispatcher, IERC721DispatcherTrait, ERC721},
    simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount}
};

const ACCOUNT: felt252 = 1234;
const ACCOUNT2: felt252 = 5729;
const SALT: felt252 = 123;


// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (
    ContractAddress, ContractAddress, ContractAddress, ContractClass, ContractClass, ContractAddress
) {
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

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    dispatcher.mint(recipient, 1.try_into().unwrap());

    // deploy registry contract
    let registry_contract = declare("Registry").unwrap();
    let (registry_contract_address, _) = registry_contract.deploy(@array![]).unwrap();

    // deploy account contract
    let account_contract_class = declare("AccountPreset").unwrap();
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(),
        1,
        0,
        registry_contract_address.try_into().unwrap(),
        account_contract_class.class_hash.into(),
        20
    ];

    let (account_contract_address, _) = account_contract_class
        .deploy(@acct_constructor_calldata)
        .unwrap();

    // deploy account V3 contract
    let account_v3_contract_class = declare("AccountV3").unwrap();
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(),
        1,
        0,
        registry_contract_address.try_into().unwrap(),
        account_contract_class.class_hash.into(),
        20
    ];

    let (account_v3_contract_address, _) = account_v3_contract_class
        .deploy(@acct_constructor_calldata)
        .unwrap();

    (
        account_contract_address,
        erc721_contract_address,
        registry_contract_address,
        recipient_contract_class,
        account_contract_class,
        account_v3_contract_address
    )
}


#[test]
fn test_on_erc721_received() {
    let (contract_address, erc721_contract_address, _, _, _, account_v3_contract_address) =
        __setup__();
    let dispatcher = IAccountDispatcher { contract_address };
    let dispatcher_v3 = IAccountV3Dispatcher { contract_address: account_v3_contract_address };
    let owner = dispatcher.owner();
    let (token_contract, token_id, chain_id) = dispatcher.token();

    let mut extra_data = array![];
    start_cheat_caller_address(account_v3_contract_address, owner);
    let on_erc721_received = dispatcher_v3
        .on_erc721_received(owner, token_contract, token_id, extra_data.span());
    println!("result of on_erc721_received: {:?}", on_erc721_received);
    stop_cheat_caller_address(account_v3_contract_address);
}

#[test]
#[should_panic(expected: ('Account: ownership cycle!',))]
fn test_on_erc721_received_fail() {
    let (contract_address, erc721_contract_address, _, _, _, account_v3_contract_address) =
        __setup__();
    let dispatcher = IAccountDispatcher { contract_address };
    let dispatcher_v3 = IAccountV3Dispatcher { contract_address: account_v3_contract_address };

    let owner = dispatcher.owner();
    // start_cheat_chain_id(account_v3_contract_address, 45689);
    let (token_contract, token_id, chain_id) = dispatcher.token();
    //  stop_cheat_chain_id(account_v3_contract_address);
    println!("result of token_contract : {:?}", token_contract);

    println!("result of token_id : {:?}", token_id);
    println!("result of chain_id: {:?}", chain_id);
    //  println!("result of target address caller: {:?}", ACCOUNT2.try_into().unwrap());
    let mut extra_data = array![];
    start_cheat_caller_address(account_v3_contract_address, token_contract);
    start_cheat_chain_id(account_v3_contract_address, 45689);
    // start_cheat_chain_id_global(56940495);
    let on_erc721_received = dispatcher_v3
        .on_erc721_received(owner, token_contract, token_id, extra_data.span());
    println!("result of on_erc721_received: {:?}", on_erc721_received);
    // stop_cheat_chain_id(account_v3_contract_address);
// stop_cheat_chain_id_global();
}

