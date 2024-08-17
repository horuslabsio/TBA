use starknet::{ContractAddress, account::Call};
use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, spy_events, EventSpyAssertionsTrait, ContractClassTrait, ContractClass
};

use token_bound_accounts::interfaces::IAccount::{
    IAccountDispatcher, IAccountDispatcherTrait, IAccountSafeDispatcher, IAccountSafeDispatcherTrait
};
use token_bound_accounts::components::presets::account_preset::AccountPreset;
use token_bound_accounts::components::account::account::AccountComponent;

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

fn __setup__() -> (ContractAddress, ContractAddress) {
    // deploy erc721 helper contract
    let erc721_contract = declare("ERC721").unwrap();
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let (erc721_contract_address, _) = erc721_contract.deploy(@erc721_constructor_calldata).unwrap();

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
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(), 1, 0
    ];
    let (account_contract_address, _) = account_contract.deploy(@acct_constructor_calldata).unwrap();

    (account_contract_address, erc721_contract_address)
}

#[test]
fn test_constructor() {
    let (contract_address, erc721_contract_address) = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };

    let (token_contract, token_id, chain_id) = dispatcher.token();
    assert(chain_id == 'SN_SEPOLIA', 'invalid chain id');
    assert(token_contract == erc721_contract_address, 'invalid token address');
    assert(token_id.low == 1.try_into().unwrap(), 'invalid token id');
}

#[test]
fn test_event_is_emitted_on_initialization() {
    // deploy erc721 contract
    let erc721_contract = declare("ERC721").unwrap();
    let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
    let (erc721_contract_address, _) = erc721_contract.deploy(@erc721_constructor_calldata).unwrap();

    // mint a new token
    let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    dispatcher.mint(ACCOUNT.try_into().unwrap(), 1.try_into().unwrap());

    // spy on emitted events
    let mut spy = spy_events();

    // deploy account contract
    let account_contract = declare("AccountPreset").unwrap();
    let mut acct_constructor_calldata = array![
        erc721_contract_address.try_into().unwrap(), 1, 0
    ];
    let (account_contract_address, _) = account_contract.deploy(@acct_constructor_calldata).unwrap();

    // check events are emitted
    spy.assert_emitted(@array![
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
    ]);
}

#[test]
fn test_is_valid_signature() {
    let (contract_address, erc721_contract_address) = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    start_cheat_caller_address(contract_address, token_owner);
    let mut good_signature = array![data.r, data.s];
    let is_valid = dispatcher.is_valid_signature(hash, good_signature.span());
    assert(is_valid == 'VALID', 'should accept valid signature');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, ACCOUNT2.try_into().unwrap());
    let mut bad_signature = array![0x284, 0x492];
    let is_valid = dispatcher.is_valid_signature(hash, bad_signature.span());
    assert(is_valid == 0, 'should reject invalid signature');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_is_valid_signer() {
    let (contract_address, erc721_contract_address) = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());

    // check for valid signer
    let valid_signer = dispatcher.is_valid_signer(token_owner);
    let invalid_signer = dispatcher.is_valid_signer(ACCOUNT.try_into().unwrap());
    assert(valid_signer == true, 'signer is meant to be valid!');
    assert(invalid_signer == false, 'signer is meant to be invalid!');
}

#[test]
fn test_token() {
    let (contract_address, erc721_contract_address) = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };

    let (token_contract, token_id, chain_id) = dispatcher.token();
    assert(chain_id == 'SN_SEPOLIA', 'invalid chain id');
    assert(token_contract == erc721_contract_address, 'invalid token address');
    assert(token_id.low == 1.try_into().unwrap(), 'invalid token id');
}

#[test]
fn test_owner() {
    let (contract_address, erc721_contract_address) = __setup__();
    let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };
    let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };

    let owner = acct_dispatcher.owner();
    let token_owner = token_dispatcher.ownerOf(1.try_into().unwrap());
    assert(owner == token_owner, 'invalid owner');
}