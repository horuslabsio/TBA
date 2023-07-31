#[starknet::interface]
use starknet::ArrayTrait;
use starknet::SpanTrait;
use starknet::ContractAddress;

trait IAccount<TContractState>{
    fn __execute__(self: @TContractState, calls:Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TContractState, calls:Array<Call>) -> felt252;
    fn __validate_declare__(self:@TContractState, class_hash:felt252) -> felt252;
    fn __validate_deploy__(self: @TContractState, class_hash:felt252, contract_address_salt:felt252, public_key:felt252) -> felt252;
    fn set_public_key(ref self: TContractState, new_public_key:felt252);
    fn get_public_key(self: @TContractState) -> felt252;
    fn is_valid_signature(self:@TContractState, hash:felt252, signature:Array<felt252>) -> felt252;
    fn support_interface(self:@TContractState, interface_id:felt252) -> bool;
    fn token(self:@TContractState) -> (token_contract, token_id);
    fn owner(slef:@TContractState) -> ContractAddress; 
}