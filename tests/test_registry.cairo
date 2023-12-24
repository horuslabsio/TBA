use starknet::{ContractAddress, contract_address_to_felt252, class_hash_to_felt252};
use traits::TryInto;
use array::{ArrayTrait, SpanTrait};
use result::ResultTrait;
use option::OptionTrait;
use integer::u256_from_felt252;
use snforge_std::{declare, start_prank, stop_prank, ContractClassTrait, ContractClass, io::PrintTrait};

use token_bound_accounts::interfaces::IRegistry::IRegistryDispatcherTrait;
use token_bound_accounts::interfaces::IRegistry::IRegistryDispatcher;
use token_bound_accounts::registry::registry::Registry;

use token_bound_accounts::interfaces::IAccount::IAccountDispatcher;
use token_bound_accounts::interfaces::IAccount::IAccountDispatcherTrait;
use token_bound_accounts::account::account::Account;

use token_bound_accounts::test_helper::erc721_helper::IERC721Dispatcher;
use token_bound_accounts::test_helper::erc721_helper::IERC721DispatcherTrait;
use token_bound_accounts::test_helper::erc721_helper::ERC721;

const ACCOUNT: felt252 = 1234;

fn __setup__() -> (ContractAddress, ContractAddress) {
    // deploy erc721 helper contract
    let erc721_contract = declare('ERC721');
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let erc721_contract_address = erc721_contract.deploy(@erc721_constructor_calldata).unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let recipient: ContractAddress = ACCOUNT.try_into().unwrap();
    dispatcher.mint(recipient, u256_from_felt252(1));

    // deploy registry contract
    let registry_contract = declare('Registry');
    let registry_contract_address = registry_contract.deploy(@array![]).unwrap();

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
    let acct_class_hash = declare('Account').class_hash;
    let account_address = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), erc721_contract_address, u256_from_felt252(1), 245828);
    
    // check total_deployed_accounts
    let total_deployed_accounts = registry_dispatcher.total_deployed_accounts(erc721_contract_address, u256_from_felt252(1));
    assert(total_deployed_accounts == 1_u8, 'invalid deployed TBA count');

    // confirm account deployment by checking the account owner
    let acct_dispatcher = IAccountDispatcher { contract_address: account_address };
    let TBA_owner = acct_dispatcher.owner(erc721_contract_address, u256_from_felt252(1));
    assert(TBA_owner == token_owner, 'acct deployed wrongly');
}

#[test]
fn test_getting_total_deployed_accounts() {
    let (registry_contract_address, erc721_contract_address) = __setup__();
    let registry_dispatcher =  IRegistryDispatcher { contract_address: registry_contract_address };

    // prank contract as token owner
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };  
    let token_owner = token_dispatcher.owner_of(u256_from_felt252(1));
    start_prank(registry_contract_address, token_owner);

    let acct_class_hash = declare('Account').class_hash;
    // create multiple accounts for same NFT
    let account_address1 = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), erc721_contract_address, u256_from_felt252(1), 3554633);
    let account_address2 = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), erc721_contract_address, u256_from_felt252(1), 363256);
    let account_address3 = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), erc721_contract_address, u256_from_felt252(1), 484734);

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
    let acct_class_hash = declare('Account').class_hash;
    let account_address = registry_dispatcher.create_account(class_hash_to_felt252(acct_class_hash), erc721_contract_address, u256_from_felt252(1), 252520);

    // get account
    let account = registry_dispatcher.get_account(class_hash_to_felt252(acct_class_hash), erc721_contract_address, u256_from_felt252(1), 252520);

    // compare both addresses
    assert(account == account_address, 'get_account computes wrongly');
}