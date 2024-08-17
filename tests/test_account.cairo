// use starknet::{ContractAddress, contract_address_to_felt252, account::Call};
// use core::integer::u256_from_felt252;
// use snforge_std::{
//     declare, start_prank, stop_prank, start_warp, stop_warp, ContractClassTrait, ContractClass,
//     CheatTarget
// };

// use token_bound_accounts::interfaces::IAccount::{
//     IAccountDispatcher, IAccountDispatcherTrait, IAccountSafeDispatcher, IAccountSafeDispatcherTrait
// };
// use token_bound_accounts::presets::account::Account;
// use token_bound_accounts::interfaces::IUpgradeable::{
//     IUpgradeableDispatcher, IUpgradeableDispatcherTrait
// };

// use token_bound_accounts::test_helper::{
//     hello_starknet::{IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, HelloStarknet},
//     account_upgrade::{IUpgradedAccountDispatcher, IUpgradedAccountDispatcherTrait, UpgradedAccount},
//     erc721_helper::{IERC721Dispatcher, IERC721DispatcherTrait, ERC721},
//     simple_account::{ISimpleAccountDispatcher, ISimpleAccountDispatcherTrait, SimpleAccount}
// };

// const ACCOUNT: felt252 = 1234;
// const ACCOUNT2: felt252 = 5729;
// const SALT: felt252 = 123;

// #[derive(Drop)]
// struct SignedTransactionData {
//     private_key: felt252,
//     public_key: felt252,
//     transaction_hash: felt252,
//     r: felt252,
//     s: felt252
// }

// fn SIGNED_TX_DATA() -> SignedTransactionData {
//     SignedTransactionData {
//         private_key: 1234,
//         public_key: 883045738439352841478194533192765345509759306772397516907181243450667673002,
//         transaction_hash: 2717105892474786771566982177444710571376803476229898722748888396642649184538,
//         r: 3068558690657879390136740086327753007413919701043650133111397282816679110801,
//         s: 3355728545224320878895493649495491771252432631648740019139167265522817576501
//     }
// }

// fn __setup__() -> (ContractAddress, ContractAddress) {
//     // deploy erc721 helper contract
//     let erc721_contract = declare("ERC721");
//     let mut erc721_constructor_calldata = array!['tokenbound', 'TBA'];
//     let erc721_contract_address = erc721_contract.deploy(@erc721_constructor_calldata).unwrap();

//     // deploy recipient contract
//     let account_contract = declare("SimpleAccount");
//     let mut recipient = account_contract
//         .deploy(
//             @array![883045738439352841478194533192765345509759306772397516907181243450667673002]
//         )
//         .unwrap();

//     // mint a new token
//     let dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     dispatcher.mint(recipient, u256_from_felt252(1));

//     // deploy account contract
//     let account_contract = declare("Account");
//     let mut acct_constructor_calldata = array![
//         contract_address_to_felt252(erc721_contract_address), 1, 0
//     ];
//     let account_contract_address = account_contract.deploy(@acct_constructor_calldata).unwrap();

//     (account_contract_address, erc721_contract_address)
// }

// #[test]
// fn test_constructor() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };

//     let (token_contract, token_id) = dispatcher.token();
//     assert(token_contract == erc721_contract_address, 'invalid token address');
//     assert(token_id.low == 1.try_into().unwrap(), 'invalid token id');
// }

// #[test]
// fn test_is_valid_signature() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };
//     let data = SIGNED_TX_DATA();
//     let hash = data.transaction_hash;

//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     start_prank(CheatTarget::One(contract_address), token_owner);
//     let mut good_signature = array![data.r, data.s];
//     let is_valid = dispatcher.is_valid_signature(hash, good_signature.span());
//     assert(is_valid == 'VALID', 'should accept valid signature');
//     stop_prank(CheatTarget::One(contract_address));

//     start_prank(CheatTarget::One(contract_address), ACCOUNT2.try_into().unwrap());
//     let mut bad_signature = array![0x284, 0x492];
//     let is_valid = dispatcher.is_valid_signature(hash, bad_signature.span());
//     assert(is_valid == 0, 'should reject invalid signature');
//     stop_prank(CheatTarget::One(contract_address));
// }

// #[test]
// fn test_execute() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };

//     // deploy `HelloStarknet` contract for testing
//     let test_contract = declare("HelloStarknet");
//     let test_address = test_contract.deploy(@array![]).unwrap();

//     // craft calldata for call array
//     let mut calldata = array![100].span();
//     let call = Call {
//         to: test_address,
//         selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
//         calldata: calldata
//     };

//     // construct call array
//     let mut calls = array![call];

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // start prank
//     start_prank(CheatTarget::One(contract_address), token_owner);

//     // make calls
//     dispatcher.__execute__(calls);

//     // check test contract state was updated
//     let test_dispatcher = IHelloStarknetDispatcher { contract_address: test_address };
//     let balance = test_dispatcher.get_balance();
//     assert(balance == 100, 'execute was not successful');
// }

// #[test]
// fn test_execute_multicall() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };

//     // deploy `HelloStarknet` contract for testing
//     let test_contract = declare("HelloStarknet");
//     let test_address = test_contract.deploy(@array![]).unwrap();

//     // craft calldata and create call array
//     let mut calldata = array![100];
//     let call1 = Call {
//         to: test_address,
//         selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
//         calldata: calldata.span()
//     };
//     let mut calldata2 = array![200];
//     let call2 = Call {
//         to: test_address,
//         selector: 1157683809588496510300162709548024577765603117833695133799390448986300456129,
//         calldata: calldata2.span()
//     };

//     // construct call array
//     let mut calls = array![call1, call2];

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // start prank
//     start_prank(CheatTarget::One(contract_address), token_owner);

//     // make calls
//     dispatcher.__execute__(calls);

//     // check test contract state was updated
//     let test_dispatcher = IHelloStarknetDispatcher { contract_address: test_address };
//     let balance = test_dispatcher.get_balance();
//     assert(balance == 500, 'execute was not successful');
// }

// #[test]
// fn test_token() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };

//     let (token_contract, token_id) = dispatcher.token();
//     assert(token_contract == erc721_contract_address, 'invalid token address');
//     assert(token_id.low == 1.try_into().unwrap(), 'invalid token id');
// }

// #[test]
// fn test_owner() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let acct_dispatcher = IAccountDispatcher { contract_address: contract_address };
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };

//     let owner = acct_dispatcher.owner();
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));
//     assert(owner == token_owner, 'invalid owner');
// }

// #[test]
// fn test_upgrade() {
//     let (contract_address, erc721_contract_address) = __setup__();

//     let new_class_hash = declare("UpgradedAccount").class_hash;

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // call the upgrade function
//     let dispatcher = IUpgradeableDispatcher { contract_address };
//     start_prank(CheatTarget::One(contract_address), token_owner);
//     dispatcher.upgrade(new_class_hash);

//     // try to call the version function
//     let upgraded_dispatcher = IUpgradedAccountDispatcher { contract_address };
//     let version = upgraded_dispatcher.version();
//     assert(version == 1_u8, 'upgrade unsuccessful');
//     stop_prank(CheatTarget::One(contract_address));
// }

// #[test]
// #[should_panic(expected: ('Account: unauthorized',))]
// fn test_upgrade_with_unauthorized() {
//     let (contract_address, _) = __setup__();

//     let new_class_hash = declare("UpgradedAccount").class_hash;

//     // call upgrade function with an unauthorized address
//     start_prank(CheatTarget::One(contract_address), ACCOUNT2.try_into().unwrap());
//     let safe_upgrade_dispatcher = IUpgradeableDispatcher { contract_address };
//     safe_upgrade_dispatcher.upgrade(new_class_hash);
// }

// #[test]
// fn test_locking() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };
//     let lock_duration = 3000_u64;

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // lock account
//     start_prank(CheatTarget::One(contract_address), token_owner);
//     start_warp(CheatTarget::One(contract_address), 1000);
//     dispatcher.lock(lock_duration);
//     stop_warp(CheatTarget::One(contract_address));

//     // check locking works
//     start_warp(CheatTarget::One(contract_address), 2000);
//     let (status, time_left) = dispatcher.is_locked();
//     stop_warp(CheatTarget::One(contract_address));

//     assert(status == true, 'account is meant to be locked');
//     assert(time_left == 2000, 'incorrect time left');
// }

// #[test]
// #[feature("safe_dispatcher")]
// fn test_should_not_execute_when_locked() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let safe_dispatcher = IAccountSafeDispatcher { contract_address };
//     let dispatcher = IAccountDispatcher { contract_address };
//     let lock_duration = 3000_u64;

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // lock account
//     start_prank(CheatTarget::One(contract_address), token_owner);
//     start_warp(CheatTarget::One(contract_address), 1000);
//     dispatcher.lock(lock_duration);
//     stop_warp(CheatTarget::One(contract_address));

//     // deploy `HelloStarknet` contract for testing purposes
//     let test_contract = declare("HelloStarknet");
//     let test_address = test_contract.deploy(@array![]).unwrap();

//     // confirm call to execute fails
//     let mut calldata = array![100];
//     let call = Call {
//         to: test_address,
//         selector: 1530486729947006463063166157847785599120665941190480211966374137237989315360,
//         calldata: calldata.span()
//     };
//     let mut calls = array![call];

//     match safe_dispatcher.__execute__(calls) {
//         Result::Ok(_) => panic(array!['should have panicked!']),
//         Result::Err(panic_data) => {
//             stop_prank(CheatTarget::One(contract_address));
//             println!("panic_data: {:?}", panic_data);
//             return ();
//         }
//     }
// }

// #[test]
// #[should_panic(expected: ('Account: account is locked!',))]
// fn test_should_not_upgrade_when_locked() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };

//     let lock_duration = 3000_u64;

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // lock account
//     start_prank(CheatTarget::One(contract_address), token_owner);
//     start_warp(CheatTarget::One(contract_address), 1000);
//     dispatcher.lock(lock_duration);
//     stop_warp(CheatTarget::One(contract_address));

//     let new_class_hash = declare("UpgradedAccount").class_hash;

//     // call the upgrade function
//     let dispatcher_upgradable = IUpgradeableDispatcher { contract_address };
//     dispatcher_upgradable.upgrade(new_class_hash);
// }

// #[test]
// #[feature("safe_dispatcher")]
// fn test_should_not_lock_if_not_owner() {
//     let (contract_address, _) = __setup__();
//     let dispatcher = IAccountSafeDispatcher { contract_address };
//     let lock_duration = 3000_u64;

//     // call the lock function
//     start_prank(CheatTarget::One(contract_address), ACCOUNT2.try_into().unwrap());
//     start_warp(CheatTarget::One(contract_address), 1000);
//     match dispatcher.lock(lock_duration) {
//         Result::Ok(_) => panic(array!['should have panicked!']),
//         Result::Err(panic_data) => {
//             stop_prank(CheatTarget::One(contract_address));
//             stop_warp(CheatTarget::One(contract_address));
//             println!("panic_data: {:?}", panic_data);
//             return ();
//         }
//     }
// }

// #[test]
// #[feature("safe_dispatcher")]
// fn test_should_not_lock_if_already_locked() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let safe_dispatcher = IAccountSafeDispatcher { contract_address };
//     let dispatcher = IAccountDispatcher { contract_address };
//     let lock_duration = 3000_u64;

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // lock account
//     start_prank(CheatTarget::One(contract_address), token_owner);
//     start_warp(CheatTarget::One(contract_address), 1000);
//     dispatcher.lock(lock_duration);
//     stop_warp(CheatTarget::One(contract_address));

//     // call the lock function again
//     start_warp(CheatTarget::One(contract_address), 1000);
//     match safe_dispatcher.lock(lock_duration) {
//         Result::Ok(_) => panic(array!['should have panicked!']),
//         Result::Err(panic_data) => {
//             stop_prank(CheatTarget::One(contract_address));
//             stop_warp(CheatTarget::One(contract_address));
//             println!("panic_data: {:?}", panic_data);
//             return ();
//         }
//     }
// }

// #[test]
// fn test_should_unlock_once_duration_ends() {
//     let (contract_address, erc721_contract_address) = __setup__();
//     let dispatcher = IAccountDispatcher { contract_address };
//     let lock_duration = 3000_u64;

//     // get token owner
//     let token_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
//     let token_owner = token_dispatcher.ownerOf(u256_from_felt252(1));

//     // lock account
//     start_prank(CheatTarget::One(contract_address), token_owner);
//     start_warp(CheatTarget::One(contract_address), 1000);
//     dispatcher.lock(lock_duration);
//     stop_warp(CheatTarget::One(contract_address));

//     // check account is unlocked if duration is exceeded
//     start_warp(CheatTarget::One(contract_address), 6000);
//     let (status, time_left) = dispatcher.is_locked();
//     stop_warp(CheatTarget::One(contract_address));

//     assert(status == false, 'account is meant to be unlocked');
//     assert(time_left == 0, 'incorrect time left');
// }
