use starknet::ContractAddress;
use traits::TryInto;
use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use cheatcodes::PreparedContract;
use forge_print::PrintTrait;

use TBA::account::account::IAccountDispatcher;
use TBA::account::account::IAccountDispatcherTrait;
use TBA::account::account::Account;

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBKEY: felt252 = 0x789789;
const TOKEN: felt252 = 0x242424;
const ID: felt252 = 1;

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

fn __setup__() -> ContractAddress {
    let class_hash = declare('Account').unwrap();

    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(PUBLIC_KEY);
    constructor_calldata.append(TOKEN);
    constructor_calldata.append(ID);
    constructor_calldata.append(0);

    let prepared = PreparedContract { class_hash: class_hash, constructor_calldata: @constructor_calldata };
    let contract_address = deploy(prepared).unwrap();
    let contract_address: ContractAddress = contract_address.try_into().unwrap();

    contract_address
}

#[test]
fn test_constructor() {
    let contract_address = __setup__();
    let dispatcher = IAccountDispatcher { contract_address };

    let pubkey = dispatcher.get_public_key();
    assert(pubkey == PUBLIC_KEY, 'invalid public key');

    let (token_contract, token_id) = dispatcher.token();
    assert(token_contract == TOKEN.try_into().unwrap(), 'invalid token address');
    assert(token_id.low == ID.try_into().unwrap(), 'invalid token id');
}