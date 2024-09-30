// *************************************************************************
//                              BASE ACCOUNT INTERFACE
// *************************************************************************
use starknet::ContractAddress;

// SRC5 interface
pub const TBA_INTERFACE_ID: felt252 =
    0x2f8e98cc382ee33eaee204ec389718628a8ce59efa3eb7e72e4d5c0f2dfa06b;

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn token(self: @TContractState) -> (ContractAddress, u256, felt252);
    fn state(self: @TContractState) -> u256;
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}
