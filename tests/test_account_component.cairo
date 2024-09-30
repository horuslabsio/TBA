// *************************************************************************
//                              ACCOUNT COMPONENT TEST
// *************************************************************************
use starknet::{ContractAddress, account::Call};
use snforge_std::{
    declare, start_cheat_caller_address, start_cheat_transaction_hash, start_cheat_nonce,
    spy_events, EventSpyAssertionsTrait, ContractClass, ContractClassTrait, DeclareResultTrait
};
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

use token_bound_accounts::interfaces::IAccount::{IAccountDispatcher, IAccountDispatcherTrait};
use token_bound_accounts::interfaces::IExecutable::{
    IExecutableDispatcher, IExecutableDispatcherTrait
};
use token_bound_accounts::interfaces::IERC721::{IERC721Dispatcher, IERC721DispatcherTrait};
use token_bound_accounts::components::account::account::AccountComponent;

use token_bound_accounts::test_helper::{
    hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait},
};

const ACCOUNT: felt252 = 1234;
const ACCOUNT2: felt252 = 5729;
const SALT: felt252 = 123;

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (
    ContractAddress, ContractAddress, ContractAddress, ContractClass, ContractClass
) {
    // deploy erc721 helper contract
    let erc721_contract = declare("ERC721").unwrap().contract_class();
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let (erc721_contract_address, _) = erc721_contract
        .deploy(@erc721_constructor_calldata)
        .unwrap();

    // deploy recipient contract
    let recipient_contract_class = declare("SimpleAccount").unwrap().contract_class();
    let (recipient, _) = recipient_contract_class
        .deploy(
            @array![883045738439352841478194533192765345509759306772397516907181243450667673002]
        )
        .unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    dispatcher.mint(recipient, 1.try_into().unwrap());

    // deploy registry contract
    let registry_contract = declare("Registry").unwrap().contract_class();
    let (registry_contract_address, _) = registry_contract.deploy(@array![]).unwrap();

    // deploy account contract
    let account_contract_class = declare("AccountPreset").unwrap().contract_class();
    let mut acct_constructor_calldata: Array<felt252> = array![
        erc721_contract_address.try_into().unwrap(),
        1,
        0,
        registry_contract_address.try_into().unwrap(),
        (*account_contract_class.class_hash).into(),
        20
    ];
    let (account_contract_address, _) = account_contract_class
        .deploy(@acct_constructor_calldata)
        .unwrap();

    (
        account_contract_address,
        erc721_contract_address,
        registry_contract_address,
        *recipient_contract_class,
        *account_contract_class
    )
}

// *************************************************************************
//                              TESTS
// *************************************************************************
#[test]
fn test_constructor() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };

    let (token_contract, token_id, chain_id) = dispatcher.token();
    assert(chain_id == 'SN_SEPOLIA', 'invalid chain id');
    assert(token_contract == erc721_contract_address, 'invalid token address');
    assert(token_id.low == 1.try_into().unwrap(), 'invalid token id');
}

#[test]
fn test_event_is_emitted_on_initialization() {
    // deploy erc721 helper contract
    let erc721_contract = declare("ERC721").unwrap().contract_class();
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let (erc721_contract_address, _) = erc721_contract
        .deploy(@erc721_constructor_calldata)
        .unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    dispatcher.mint(ACCOUNT.try_into().unwrap(), 1.try_into().unwrap());

    // spy on emitted events
    let mut spy = spy_events();

    // deploy registry contract
    let registry_contract = declare("Registry").unwrap().contract_class();
    let (registry_contract_address, _) = registry_contract.deploy(@array![]).unwrap();

    // deploy account contract
    let account_contract = declare("AccountPreset").unwrap().contract_class();
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(),
        1,
        0,
        registry_contract_address.try_into().unwrap(),
        (*account_contract.class_hash).into(),
        20
    ];
    let (account_contract_address, _) = account_contract
        .deploy(@acct_constructor_calldata)
        .unwrap();

    // check events are emitted
    spy
        .assert_emitted(
            @array![
                (
                    account_contract_address,
                    AccountComponent::Event::TBACreated(
                        AccountComponent::TBACreated {
                            account_address: account_contract_address,
                            parent_account: ACCOUNT.try_into().unwrap(),
                            token_contract: erc721_contract_address,
                            token_id: 1.try_into().unwrap()
                        }
                    )
                )
            ]
        );
}

#[test]
fn test_execute() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let dispatcher = IExecutableDispatcher { contract_address };

    // deploy `HelloStarknet` contract for testing
    let test_contract = declare("HelloStarknet").unwrap().contract_class();
    let (test_address, _) = test_contract.deploy(@array![]).unwrap();

    // craft calldata for call array
    let mut calldata = array![100].span();
    let call = Call {
        to: test_address,
        selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
        calldata: calldata
    };

    // construct call array
    let mut calls = array![call];

    // get token owner to prank contract
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    start_cheat_caller_address(contract_address, token_owner);

    // make calls
    dispatcher.execute(calls);

    // check test contract state was updated
    let test_dispatcher = IHelloStarknetDispatcher { contract_address: test_address };
    let balance = test_dispatcher.get_balance();
    assert(balance == 100, 'execute was not successful');
}

#[test]
fn test_execute_multicall() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let dispatcher = IExecutableDispatcher { contract_address };

    // deploy `HelloStarknet` contract for testing
    let test_contract = declare("HelloStarknet").unwrap().contract_class();
    let (test_address, _) = test_contract.deploy(@array![]).unwrap();

    // craft calldata and create call array
    let mut calldata = array![100];
    let call1 = Call {
        to: test_address,
        selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
        calldata: calldata.span()
    };
    let mut calldata2 = array![200];
    let call2 = Call {
        to: test_address,
        selector: 1157683809588496510300162709548024577765603117833695133799390448986300456129,
        calldata: calldata2.span()
    };

    // construct call array
    let mut calls = array![call1, call2];

    // get token owner to prank contract
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    start_cheat_caller_address(contract_address, token_owner);

    // make calls
    dispatcher.execute(calls);

    // check test contract state was updated
    let test_dispatcher = IHelloStarknetDispatcher { contract_address: test_address };
    let balance = test_dispatcher.get_balance();
    assert(balance == 500, 'execute was not successful');
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_execution_fails_if_invalid_signer() {
    let (contract_address, _, _, _, _) = __setup__();
    let dispatcher = IExecutableDispatcher { contract_address };

    // deploy `HelloStarknet` contract for testing
    let test_contract = declare("HelloStarknet").unwrap().contract_class();
    let (test_address, _) = test_contract.deploy(@array![]).unwrap();

    // craft calldata for call array
    let mut calldata = array![100].span();
    let call = Call {
        to: test_address,
        selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
        calldata: calldata
    };
    let mut calls = array![call];

    // prank with invalid owner
    start_cheat_caller_address(contract_address, ACCOUNT.try_into().unwrap());

    // make calls
    dispatcher.execute(calls);
}

#[test]
fn test_execution_emits_event() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let dispatcher = IExecutableDispatcher { contract_address };

    // deploy `HelloStarknet` contract for testing
    let test_contract = declare("HelloStarknet").unwrap().contract_class();
    let (test_address, _) = test_contract.deploy(@array![]).unwrap();

    // craft calldata for call array
    let mut calldata = array![100].span();
    let call = Call {
        to: test_address,
        selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
        calldata: calldata
    };
    let mut calls = array![call];

    // get token owner to prank contract
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    // pranks
    start_cheat_caller_address(contract_address, token_owner);
    start_cheat_transaction_hash(contract_address, 121432345);

    // spy on emitted events
    let mut spy = spy_events();

    // make calls
    let retdata = dispatcher.execute(calls);

    // check events are emitted
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    AccountComponent::Event::TransactionExecuted(
                        AccountComponent::TransactionExecuted {
                            hash: 121432345,
                            account_address: contract_address,
                            response: retdata.span()
                        }
                    )
                )
            ]
        );
}

#[test]
fn test_execution_updates_state() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let dispatcher = IExecutableDispatcher { contract_address };
    let account_dispatcher = IAccountDispatcher { contract_address };

    // deploy `HelloStarknet` contract for testing
    let test_contract = declare("HelloStarknet").unwrap().contract_class();
    let (test_address, _) = test_contract.deploy(@array![]).unwrap();

    // craft calldata for call array
    let mut calldata = array![100].span();
    let call = Call {
        to: test_address,
        selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
        calldata: calldata
    };
    let mut calls = array![call];

    // get token owner to prank contract
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    // pranks
    let nonce = 20;
    start_cheat_caller_address(contract_address, token_owner);
    start_cheat_nonce(contract_address, nonce);

    // calculate intended state
    let old_state = account_dispatcher.state();
    dispatcher.execute(calls);
    let new_state = PedersenTrait::new(old_state.try_into().unwrap()).update(nonce).finalize();

    // retrieve and check new state aligns with intended
    let state = account_dispatcher.state();
    assert(state == new_state.try_into().unwrap(), 'invalid state!');
}

#[test]
fn test_token() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };

    let (token_contract, token_id, chain_id) = dispatcher.token();
    assert(chain_id == 'SN_SEPOLIA', 'invalid chain id');
    assert(token_contract == erc721_contract_address, 'invalid token address');
    assert(token_id.low == 1.try_into().unwrap(), 'invalid token id');
}

#[test]
fn test_owner() {
    let (contract_address, erc721_contract_address, _, _, _) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };

    let owner = acct_dispatcher.owner();
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    assert(owner == token_owner, 'invalid owner');
}
// #[test]
// fn test_root_owner() {
//     let (_, erc721_contract_address, registry_contract_address, simple_account_class,
//     account_class) = __setup__();

//     // deploy recipient contract
//     let (recipient, _) = simple_account_class
//         .deploy(
//             @array![883045738439352841478194533192765345509759306772397516907181243450667673002]
//         )
//         .unwrap();

//     // mint a new token to recipient
//     let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     dispatcher.mint(recipient, 1.try_into().unwrap());

//     // deploy account 1
//     start_cheat_caller_address(registry_contract_address, recipient);
//     let registry_dispatcher = IRegistryDispatcher { contract_address: registry_contract_address
//     };
//     let account_1 = registry_dispatcher
//         .create_account(
//             account_class.class_hash.into(),
//             erc721_contract_address,
//             1.try_into().unwrap(),
//             2525201,
//             'SN_SEPOLIA'
//         );
//     stop_cheat_caller_address(registry_contract_address);

//     // mint a new token to account 1
//     dispatcher.mint(account_1, 2.try_into().unwrap());

//     // deploy account 1-2
//     start_cheat_caller_address(registry_contract_address, account_1);
//     let account_1_2 = registry_dispatcher
//         .create_account(
//             account_class.class_hash.into(),
//             erc721_contract_address,
//             2.try_into().unwrap(),
//             2525202,
//             'SN_SEPOLIA'
//         );
//     stop_cheat_caller_address(registry_contract_address);

//     // mint a new token to account 1-2
//     let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     dispatcher.mint(account_1_2, 3.try_into().unwrap());

//     // deploy account 1-2-3
//     start_cheat_caller_address(registry_contract_address, account_1_2);
//     let account_1_2_3 = registry_dispatcher
//         .create_account(
//             account_class.class_hash.into(),
//             erc721_contract_address,
//             3.try_into().unwrap(),
//             2525203,
//             'SN_SEPOLIA'
//         );
//     stop_cheat_caller_address(registry_contract_address);

//     println!("account_1_2_3: {:?}", account_1_2_3);
//     println!("account_1_2: {:?}", account_1_2);
//     println!("account_1: {:?}", account_1);
//     println!("recipient: {:?}", recipient);

//     // get root owners
//     start_cheat_account_contract_address(account_1_2_3, account_1_2_3);
//     let root_owner_for_account_1_2_3 = IAccountDispatcher { contract_address: account_1_2_3
//     }.root_owner(erc721_contract_address, 3, 'SN_SEPOLIA');
//     stop_cheat_account_contract_address(account_1_2_3);

//     start_cheat_account_contract_address(account_1_2, account_1_2);
//     let root_owner_for_account_1_2 = IAccountDispatcher { contract_address: account_1_2
//     }.root_owner(erc721_contract_address, 2, 'SN_SEPOLIA');
//     stop_cheat_account_contract_address(account_1_2);

//     start_cheat_account_contract_address(account_1, account_1);
//     let root_owner_for_account_1 = IAccountDispatcher { contract_address: account_1
//     }.root_owner(erc721_contract_address, 1, 'SN_SEPOLIA');
//     stop_cheat_account_contract_address(account_1);

//     // check root owner is valid
//     assert(root_owner_for_account_1_2_3 == recipient, 'invalid root owner');
//     assert(root_owner_for_account_1_2 == recipient, 'invalid root owner');
//     assert(root_owner_for_account_1 == recipient, 'invalid root owner');
// }


