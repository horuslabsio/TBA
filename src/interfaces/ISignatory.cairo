// *************************************************************************
//                              SIGNER VALIDATION INTERFACE
// *************************************************************************
use starknet::ContractAddress;

#[starknet::interface]
pub trait ISignatory<TContractState> {
    fn is_valid_signer(self: @TContractState, signer: ContractAddress) -> bool;
    fn is_valid_signature(
        self: @TContractState, hash: felt252, signature: Span<felt252>
    ) -> felt252;
}
