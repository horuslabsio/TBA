#[starknet::interface]
use starknet::ArrayTrait;
use starknet::SpanTrait;
use starknet::ContractAddress;

trait IAccount<TContractState>{
    fn get_public_key(self: @TContractState) -> felt252;
    fn set_public_key(ref self: TContractState, new_public_key:felt252);
    fn isValidSignature(self: @TContractState, hash:felt252, signature: Span<felt252>) -> bool;
    fn __validate__(ref self: TContractState, calls:Array<Call>) -> felt252;
    fn __validate_declare__(self:@TContractState, class_hash:felt252) -> felt252;
    fn __validate_deploy__(self: @TContractState, class_hash:felt252, contract_address_salt:felt252, public_key:felt252) -> felt252;
    fn __execute__(ref self: TContractState, calls:Array<Call>) -> Array<Span<felt252>>;
    fn token(self:@TContractState) -> (ContractAddress, u256);
    fn owner(ref self: TContractState, token_contract:ContractAddress, token_id:u256) -> ContractAddress;
    fn upgrade(ref self: TContractState, implementation: ClassHash);
}