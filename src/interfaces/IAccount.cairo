// *************************************************************************
//                              BASE ACCOUNT INTERFACE
// *************************************************************************
use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::account::Call;

// SRC5 interface for token bound accounts
pub const TBA_INTERFACE_ID: felt252 =
    0xd050d1042482f6e9a28d0c039d0a8428266bf4fd59fe95cee66d8e0e8b3b2e;

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn token(self: @TContractState) -> (ContractAddress, u256, felt252);
    fn owner(self: @TContractState) -> ContractAddress;
    fn state(self: @TContractState) -> u256;
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}
