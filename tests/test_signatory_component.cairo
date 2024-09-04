// *************************************************************************
//                              COMPONENT COMPONENT TEST
// *************************************************************************
use starknet::{ContractAddress, account::Call, get_block_timestamp};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_transaction_hash,
    start_cheat_nonce, spy_events, EventSpyAssertionsTrait, ContractClassTrait, ContractClass,
    start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;

use token_bound_accounts::interfaces::IAccount::{
    IAccountDispatcher, IAccountDispatcherTrait, IAccountSafeDispatcher, IAccountSafeDispatcherTrait
};

use token_bound_accounts::interfaces::IPermissionable::{
    IPermissionableDispatcher, IPermissionableDispatcherTrait
};

use token_bound_accounts::interfaces::ISignatory::{ISignatoryDispatcher, ISignatoryDispatcherTrait};

use token_bound_accounts::interfaces::IExecutable::{
    IExecutableDispatcher, IExecutableDispatcherTrait
};
use token_bound_accounts::interfaces::IUpgradeable::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait
};
use token_bound_accounts::components::presets::account_preset::AccountPreset;
use token_bound_accounts::components::account::account::AccountComponent;


use token_bound_accounts::components::signatory::signatory::SignatoryComponent;
use token_bound_accounts::components::permissionable::permissionable::PermissionableComponent;

use token_bound_accounts::test_helper::{
    hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, HelloStarknet},
    erc721_helper::{IERC721Dispatcher, IERC721DispatcherTrait, ERC721},
    simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount}
};

const ACCOUNT1: felt252 = 5729;
const ACCOUNT2: felt252 = 1234;
const ACCOUNT3: felt252 = 6908;
const ACCOUNT4: felt252 = 4697;

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
    dispatcher.mint(recipient, 2.try_into().unwrap());

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
fn test_is_valid_signer_for_base_owner() {
    let (contract_address, erc721_contract_address) = __setup__();

    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    let signatory_dispatcher = ISignatoryDispatcher { contract_address: contract_address };
    start_cheat_caller_address(contract_address, token_owner);
    let is_valid_signer = signatory_dispatcher.is_valid_signer(token_owner);

    assert(is_valid_signer == true, 'should be a valid signature');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_is_valid_signer_for_permissioned_addresses() {
    let (contract_address, erc721_contract_address) = __setup__();

    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    let permissionable_dispatcher = IPermissionableDispatcher { contract_address };
    let signatory_dispatcher = ISignatoryDispatcher { contract_address: contract_address };

    let mut permission_addresses = ArrayTrait::new();
    permission_addresses.append(ACCOUNT2.try_into().unwrap());
    permission_addresses.append(ACCOUNT3.try_into().unwrap());

    let mut permissions = ArrayTrait::new();
    permissions.append(true);
    permissions.append(true);

    start_cheat_caller_address(contract_address, token_owner);
    permissionable_dispatcher.set_permission(permission_addresses, permissions);
    let is_valid_signer = signatory_dispatcher.is_valid_signer(ACCOUNT2.try_into().unwrap());

    assert(is_valid_signer == true, 'should be a valid signer');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_is_valid_signer_for_root_owner() {
    let (contract_address, _) = __setup__();
    let account_dispatcher = IAccountDispatcher { contract_address };
    let (account_contract, _, _) = account_dispatcher.token();

    let root_owner = account_dispatcher.get_root_owner(account_contract, 1.try_into().unwrap());
    let signatory_dispatcher = ISignatoryDispatcher { contract_address: contract_address };

    start_cheat_caller_address(contract_address, root_owner);

    let is_valid_signer = signatory_dispatcher.is_valid_signer(root_owner);
    assert(is_valid_signer == true, 'should be a valid signer');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_is_valid_signature_for_base_owner() {
    let (contract_address, erc721_contract_address) = __setup__();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    let signatory_dispatcher = ISignatoryDispatcher { contract_address: contract_address };

    start_cheat_caller_address(contract_address, token_owner);

    let mut good_signature = array![data.r, data.s];
    let is_valid = signatory_dispatcher.is_valid_signature(hash, good_signature.span());
    assert(is_valid == 'VALID', 'should be a valid signature');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_is_valid_signature_for_root_owner() {
    let (contract_address, _) = __setup__();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let account_dispatcher = IAccountDispatcher { contract_address };
    let (account_contract, _, _) = account_dispatcher.token();

    let root_owner = account_dispatcher.get_root_owner(account_contract, 1.try_into().unwrap());
    let signatory_dispatcher = ISignatoryDispatcher { contract_address: contract_address };

    start_cheat_caller_address(contract_address, root_owner);

    let mut good_signature = array![data.r, data.s];
    let is_valid_signer = signatory_dispatcher.is_valid_signature(hash, good_signature.span());
    assert(is_valid_signer == 'VALID', 'should be a valid signature');

    stop_cheat_caller_address(contract_address);
}

