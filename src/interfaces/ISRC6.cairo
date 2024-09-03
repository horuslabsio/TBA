use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::account::Call;

#[starknet::interface]
pub trait ISRC6<TContractState> {
    fn is_valid_signature(
        self: @TContractState, hash: felt252, signature: Span<felt252>
    ) -> felt252;
    fn __validate__(ref self: TContractState, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @TContractState, class_hash: felt252) -> felt252;
    fn __validate_deploy__(
        self: @TContractState, class_hash: felt252, contract_address_salt: felt252
    ) -> felt252;
    fn __execute__(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
}
