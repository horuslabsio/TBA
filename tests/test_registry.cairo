use starknet::{ContractAddress, contract_address_to_felt252, class_hash_to_felt252};
use traits::TryInto;
use array::{ArrayTrait, SpanTrait};
use result::ResultTrait;
use option::OptionTrait;
use integer::u256_from_felt252;
use cheatcodes::PreparedContract;
use forge_print::PrintTrait;

use TBA::registry::registry::IRegistryDispatcherTrait;
use TBA::registry::registry::IRegistryDispatcher;
use TBA::registry::registry::Registry;

use TBA::account::account::IAccountDispatcher;
use TBA::account::account::IAccountDispatcherTrait;
use TBA::account::account::Account;

use TBA::test_helper::erc721_helper::IERC721Dispatcher;
use TBA::test_helper::erc721_helper::IERC721DispatcherTrait;
use TBA::test_helper::erc721_helper::ERC721;

const PUBLIC_KEY: felt252 = 883045738439352841478194533192765345509759306772397516907181243450667673002;
const PUBLIC_KEY1: felt252 = 927653455097593347819453319276534550975930677239751690718124346772397516907;
const PUBLIC_KEY2: felt252 = 308194455097593347819453319276534550975930677239751690718124346772340156493;
const ACCOUNT: felt252 = 1234;

fn __setup__() -> (ContractAddress, ContractAddress) {
    // deploy erc721 helper contract
    let erc721_class_hash = declare('ERC721');
    let mut erc721_constructor_calldata = ArrayTrait::new();
    erc721_constructor_calldata.append('tokenbound');
    erc721_constructor_calldata.append('TBA');

    let erc721_prepared = PreparedContract { class_hash: erc721_class_hash, constructor_calldata: @erc721_constructor_calldata };
    let erc721_contract_address = deploy(erc721_prepared).unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let recipient: ContractAddress = ACCOUNT.try_into().unwrap();
    dispatcher.mint(recipient, u256_from_felt252(1));

    // deploy registry contract
    let registry_class_hash = declare('Registry');
    let registry_prepared = PreparedContract { class_hash: registry_class_hash, constructor_calldata: @ArrayTrait::new() };

    let registry_contract_address = deploy(registry_prepared).unwrap();
    (registry_contract_address, erc721_contract_address)
}

#[test]
fn test_create_account() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher =  IRegistryDispatcher { contract_address: registry_contract_address };

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };  
    let token_owner = token_dispatcher.owner_of(u256_from_felt252(1));
    start_prank(registry_contract_address, token_owner);

    // create account
    let acct_class_hash = declare('Account');
    let account_address = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), PUBLIC_KEY, erc721_contract_address, u256_from_felt252(1));
    
    // check total_deployed_accounts
    let total_deployed_accounts = registry_dispatcher.total_deployed_accounts(erc721_contract_address, u256_from_felt252(1));
    assert(total_deployed_accounts == 1_u8, 'invalid deployed TBA count');

    // check account was deployed by trying to get the public key
    let acct_dispatcher = IAccountDispatcher { contract_address: account_address };
    let public_key = acct_dispatcher.get_public_key();
    assert(public_key == PUBLIC_KEY, 'acct deployed wrongly');
    account_address.print();
}

#[test]
fn test_getting_total_deployed_accounts() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher =  IRegistryDispatcher { contract_address: registry_contract_address };

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };  
    let token_owner = token_dispatcher.owner_of(u256_from_felt252(1));
    start_prank(registry_contract_address, token_owner);

    let acct_class_hash = declare('Account');
    // create multiple accounts for same NFT
    let account_address1 = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), PUBLIC_KEY, erc721_contract_address, u256_from_felt252(1));
    let account_address2 = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), PUBLIC_KEY1, erc721_contract_address, u256_from_felt252(1));
    let account_address3 = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), PUBLIC_KEY2, erc721_contract_address, u256_from_felt252(1));

    // check total_deployed_accounts
    let total_deployed_accounts = registry_dispatcher.total_deployed_accounts(erc721_contract_address, u256_from_felt252(1));
    assert(total_deployed_accounts == 3_u8, 'invalid deployed TBA count');
}

#[test]
fn test_get_account() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher =  IRegistryDispatcher { contract_address: registry_contract_address };

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };  
    let token_owner = token_dispatcher.owner_of(u256_from_felt252(1));
    start_prank(registry_contract_address, token_owner);

    // deploy account
    let acct_class_hash = declare('Account');
    let account_address = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), PUBLIC_KEY, erc721_contract_address, u256_from_felt252(1));

    // get account
    let account = registry_dispatcher.get_account(class_hash_to_felt252(acct_class_hash), PUBLIC_KEY, erc721_contract_address, u256_from_felt252(1));

    // compare both addresses
    // assert(account == account_address, 'get_account computes wrongly');
    account.print();
    account_address.print();
}