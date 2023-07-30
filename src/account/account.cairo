use core::array::ArrayTrait;
use core::array::SpanTrait;
use starknet::account::Call;
use starknet::ContractAddress;



// #[starknet::interface]
// trait IsupportInterface<TContractState>{
//     fn register_interface(self:@TContractState, interface_id: felt252) -> bool;
//     fn deresgister_interface(self:@TContractState, interface_id:felt252) -> bool;
// }

const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;
const TRANSACTION_VERSION: felt252 = 1;


#[starknet::interface]
trait IAccount<TContractState>{
    fn __execute__(ref self: TContractState, calls:Array<Call>, token_contract:ContractAddress, token_id:u256) -> Array<Span<felt252>>;
    fn __validate__(ref self: TContractState, calls:Array<Call>) -> felt252;
    fn __validate_declare__(self:@TContractState, class_hash:felt252) -> felt252;
    fn __validate_deploy__(self: @TContractState, class_hash:felt252, contract_address_salt:felt252, public_key:felt252) -> felt252;
    fn set_public_key(ref self: TContractState, new_public_key:felt252);
    fn get_public_key(self: @TContractState) -> felt252;
    fn is_valid_signature(self:@TContractState, hash:felt252, signature:Array<felt252>) -> felt252;
    // fn support_interface(self:@TContractState, interface_id:felt252) -> bool;
    fn token(self:@TContractState) -> (ContractAddress, u256);
    fn owner(ref self: TContractState, token_contract:ContractAddress, token_id:u256) -> ContractAddress; 
    fn nonce(self:@TContractState) -> felt252;
}

#[starknet::interface]
trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn safe_transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TContractState, owner: ContractAddress, operator: ContractAddress) -> bool;
    // IERC721Metadata
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;
}

#[starknet::contract]
mod Account {

use starknet::{get_tx_info, get_caller_address, get_contract_address};
use ecdsa::check_ecdsa_signature;
use array::SpanTrait;
use array::ArrayTrait;
use box::BoxTrait;
use option::OptionTrait;
use zeroable::Zeroable;
use starknet::account::Call;
use starknet::ContractAddress;
use super::IERC721DispatcherTrait;
use super::IERC721Dispatcher;

    #[storage]
    struct Storage{
        _public_key: felt252,
        _token_contract:ContractAddress,
        _token_id:u256,
    }



        #[constructor]
        fn constructor(ref self: ContractState, _public_key:felt252, token_contract:ContractAddress, token_id:u256){
        self.initializer(_public_key, token_contract, token_id);
        }


        #[external(v0)]
        impl IAccountImpl of super::IAccount<ContractState>{
            fn get_public_key(self: @ContractState) -> felt252{
                self._public_key.read()
            }

            fn set_public_key(ref self:ContractState, new_public_key:felt252){
                assert_only_self();
                self._public_key.write(new_public_key);
            }

            fn __validate_deploy__(
                self: @ContractState,
                class_hash:felt252,
                contract_address_salt:felt252,
                public_key:felt252
            ) -> felt252{
                self.validate_transaction()
            }

            fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
                        self.validate_transaction()
            }

            fn is_valid_signature(
                        self: @ContractState, hash: felt252, signature: Array<felt252>
                    ) -> felt252 {
                        if self._is_valid_signature(hash, signature.span()) {
                            starknet::VALIDATED
                        } else {
                            0
                        }
                    }

                fn __validate__( ref self: ContractState, mut calls:Array<Call>) -> felt252{
                    self.validate_transaction()
                }
                // equivalent of executeCall
                fn __execute__(ref self: ContractState, mut calls:Array<Call>, token_contract:ContractAddress, token_id:u256) -> Array<Span<felt252>>{
                let owner = IERC721Dispatcher { contract_address: token_contract }.owner_of(token_id);
                assert(owner == get_caller_address(), 'CALLER_IS_NOT_OWNER');
                    let sender = get_caller_address();
                    assert(sender.is_zero(), 'Account: invalid caller');
                        let tx_info = get_tx_info().unbox();
                        let version = tx_info.version;
                        if version != super::TRANSACTION_VERSION {
                            assert(version == super::QUERY_VERSION, 'Account: invalid tx version');
                        }

                        _execute_calls(calls)
                }

            fn owner(ref self:ContractState, token_contract:ContractAddress, token_id:u256) -> ContractAddress{
            IERC721Dispatcher { contract_address: token_contract }.owner_of(token_id)
            }

            fn nonce(self:@ContractState) -> felt252{
                let nonce = get_tx_info().unbox().nonce;
                nonce
            } 

            fn token(self:@ContractState) -> (ContractAddress, u256){
            let contract =  self._token_contract.read();
            let tokenId =  self._token_id.read();
              return (contract, tokenId);
             }
            
}



        #[generate_trait]
        impl internalImpl of InternalTrait{
            fn initializer(ref self:ContractState, public_key:felt252, token_contract:ContractAddress, token_id:u256){
                self._public_key.write(public_key);
                self._token_contract.read();
                self._token_id.read();
            }

                fn validate_transaction(self: @ContractState) -> felt252 {
                    let tx_info = get_tx_info().unbox();
                    let tx_hash = tx_info.transaction_hash;
                    let signature = tx_info.signature;
                    assert(self._is_valid_signature(tx_hash, signature), 'Account: invalid signature');
                    starknet::VALIDATED
                }


            fn _is_valid_signature(self: @ContractState, hash:felt252, signature: Span<felt252>) -> bool{
                let valid_length = signature.len() == 2_u32;

                if valid_length {
                check_ecdsa_signature(
                            hash, self._public_key.read(), *signature.at(0_u32), *signature.at(1_u32)
                        )
                }else{ 
                    false
                }


            }

        }


        #[internal]
        fn assert_only_self(){
            let caller = get_caller_address();
            let self = get_contract_address();
            assert(self == caller, 'Account: unathorized');
        }

        #[internal]
            fn _execute_calls(mut calls: Array<Call>) -> Array<Span<felt252>> {
                let mut res = ArrayTrait::new();
                loop {
                    match calls.pop_front() {
                        Option::Some(call) => {
                            let _res = _execute_single_call(call);
                            res.append(_res);
                        },
                        Option::None(_) => {
                            break ();
                        },
                    };
                };
                res
            }

            #[internal]
            fn _execute_single_call(call: Call) -> Span<felt252> {
                let Call{to, selector, calldata } = call;
                starknet::call_contract_syscall(to, selector, calldata.span()).unwrap_syscall()
            }



}